#!/usr/bin/env python3
import os
import pty
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ANSI_ESCAPE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

def clean_text(text: str) -> str:
    cleaned = ANSI_ESCAPE.sub('', text)
    return cleaned.replace('\r', '')

def has_cmd(cmd: str) -> bool:
    return shutil.which(cmd) is not None

USE_KDIALOG = has_cmd('kdialog')
USE_ZENITY = has_cmd('zenity')

def find_openconnect_auth_dialog() -> str | None:
    candidates = [
        "/usr/lib/nm-openconnect-auth-dialog",
        "/usr/libexec/nm-openconnect-auth-dialog",
        "/usr/lib/NetworkManager/nm-openconnect-auth-dialog",
        shutil.which("nm-openconnect-auth-dialog"),
    ]
    for c in candidates:
        if c and os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    return None

def get_connection_details(target: str) -> tuple[str, str, str]:
    """Returns (uuid, name, service_type)"""
    try:
        res = subprocess.run(
            ["nmcli", "-g", "connection.uuid,connection.id,vpn.service-type", "connection", "show", target],
            capture_output=True,
            text=True,
            check=True
        )
        lines = [l.strip() for l in res.stdout.strip().splitlines() if l.strip()]
        if len(lines) >= 3:
            return lines[0], lines[1], lines[2]
        elif len(lines) == 2:
            return lines[0], lines[1], ""
    except Exception:
        pass
    return target, target, ""

def get_vpn_config(uuid: str) -> tuple[dict[str, str], dict[str, str]]:
    """Gets (data_dict, secrets_dict) for the VPN connection"""
    data = {}
    secrets = {}

    try:
        import gi
        gi.require_version("NM", "1.0")
        from gi.repository import NM
        client = NM.Client.new(None)
        con = client.get_connection_by_uuid(uuid) or client.get_connection_by_id(uuid)
        if con:
            s_vpn = con.get_setting_vpn()
            if s_vpn:
                s_vpn.foreach_data_item(lambda k, v: data.update({k: v}))
                s_vpn.foreach_secret(lambda k, v: secrets.update({k: v}))
                return data, secrets
    except Exception:
        pass

    try:
        res = subprocess.run(
            ["nmcli", "-s", "-g", "vpn.data", "connection", "show", uuid],
            capture_output=True, text=True
        )
        raw = res.stdout.strip()
        if raw:
            items = re.split(r"(?<!\\),\s*", raw)
            for item in items:
                if "=" in item:
                    k, v = item.split("=", 1)
                    k = k.strip().replace(r"\:", ":").replace(r"\,", ",")
                    v = v.strip().replace(r"\:", ":").replace(r"\,", ",")
                    data[k] = v
    except Exception:
        pass

    return data, secrets

def handle_openconnect(uuid: str, vpn_name: str) -> int:
    auth_dialog = find_openconnect_auth_dialog()
    if not auth_dialog:
        return -1

    data, secrets = get_vpn_config(uuid)
    if not data or "gateway" not in data:
        return -1

    payload_lines = []
    for k, v in data.items():
        payload_lines.append(f"DATA_KEY={k}\nDATA_VAL={v}\n")
    for k, v in secrets.items():
        payload_lines.append(f"SECRET_KEY={k}\nSECRET_VAL={v}\n")
    payload_lines.append("DONE\n")
    payload = "".join(payload_lines)

    cmd = [
        auth_dialog,
        "-u", uuid,
        "-n", vpn_name,
        "-s", "org.freedesktop.NetworkManager.openconnect",
        "-i"
    ]

    try:
        proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
    except Exception as e:
        print(f"Failed to launch openconnect auth dialog: {e}", file=sys.stderr)
        return -1

    try:
        proc.stdin.write(payload)
        proc.stdin.flush()
    except Exception as e:
        print(f"Failed to pipe config to auth dialog: {e}", file=sys.stderr)
        proc.kill()
        return 1

    received_lines = []
    while True:
        if proc.poll() is not None:
            for line in proc.stdout:
                line = line.rstrip('\r\n')
                if line == "":
                    break
                received_lines.append(line)
            break

        r, _, _ = select.select([proc.stdout], [], [], 0.3)
        if not r:
            continue
        line = proc.stdout.readline()
        if not line:
            break
        line = line.rstrip('\r\n')
        if line == "":
            break
        received_lines.append(line)

    try:
        proc.stdin.write("QUIT\n")
        proc.stdin.flush()
        proc.stdin.close()
    except Exception:
        pass

    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()

    output_secrets = {}
    for i in range(0, len(received_lines) - 1, 2):
        k = received_lines[i]
        v = received_lines[i + 1]
        output_secrets[k] = v

    if not output_secrets:
        return 130

    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', delete=False, prefix='nm_vpn_pw_') as tf:
            temp_path = tf.name
            os.chmod(temp_path, 0o600)
            for k, v in output_secrets.items():
                tf.write(f"vpn.secrets.{k}:{v}\n")

        res = subprocess.run([
            'nmcli', 'connection', 'up', 'uuid', uuid, 'passwd-file', temp_path
        ])
        return res.returncode
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass

def dialog_yesno(title: str, text: str) -> bool:
    if USE_KDIALOG:
        res = subprocess.run(['kdialog', '--title', title, '--yesno', text])
        return res.returncode == 0
    elif USE_ZENITY:
        res = subprocess.run(['zenity', '--question', '--title', title, '--text', text])
        return res.returncode == 0
    return False

def dialog_input(title: str, text: str, default: str = "") -> tuple[bool, str]:
    if USE_KDIALOG:
        cmd = ['kdialog', '--title', title, '--inputbox', text]
        if default:
            cmd.append(default)
        res = subprocess.run(cmd, stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            return True, res.stdout.rstrip('\r\n')
        return False, ""
    elif USE_ZENITY:
        cmd = ['zenity', '--entry', '--title', title, '--text', text]
        if default:
            cmd.extend(['--entry-text', default])
        res = subprocess.run(cmd, stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            return True, res.stdout.rstrip('\r\n')
        return False, ""
    return False, ""

def dialog_password(title: str, text: str) -> tuple[bool, str]:
    if USE_KDIALOG:
        res = subprocess.run(['kdialog', '--title', title, '--password', text],
                             stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            return True, res.stdout.rstrip('\r\n')
        return False, ""
    elif USE_ZENITY:
        res = subprocess.run(['zenity', '--password', '--title', title, '--text', text],
                             stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            return True, res.stdout.rstrip('\r\n')
        return False, ""
    return False, ""

def dialog_error(title: str, text: str):
    if USE_KDIALOG:
        subprocess.run(['kdialog', '--title', title, '--error', text])
    elif USE_ZENITY:
        subprocess.run(['zenity', '--error', '--title', title, '--text', text])

def main():
    if len(sys.argv) < 2:
        print("Usage: connect_vpn_gui.py <uuid-or-name> [friendly-name]", file=sys.stderr)
        sys.exit(1)

    target = sys.argv[1]
    vpn_name = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else target

    uuid, resolved_name, service_type = get_connection_details(target)
    if not vpn_name or vpn_name == target:
        vpn_name = resolved_name

    if service_type == "org.freedesktop.NetworkManager.openconnect":
        ret = handle_openconnect(uuid, vpn_name)
        if ret != -1:
            sys.exit(ret)

    window_title = f"VPN Authentication - {vpn_name}"

    if not USE_KDIALOG and not USE_ZENITY:
        print("Error: Neither kdialog nor zenity found.", file=sys.stderr)
        sys.exit(1)

    master, slave = pty.openpty()
    pid = os.fork()

    if pid == 0:
        # Child process
        os.close(master)
        os.dup2(slave, 0)
        os.dup2(slave, 1)
        os.dup2(slave, 2)
        os.close(slave)
        # Force C locale for predictable prompt matching
        env = os.environ.copy()
        env['LANG'] = 'C'
        env['LC_ALL'] = 'C'
        cmd = ['nmcli', 'connection', 'up', 'uuid', target, '--ask']
        try:
            os.execvpe('nmcli', cmd, env)
        except Exception as e:
            print(f"Failed to exec nmcli: {e}", file=sys.stderr)
            sys.exit(127)

    os.close(slave)

    def kill_child():
        try:
            os.kill(pid, signal.SIGTERM)
            time.sleep(0.2)
            os.kill(pid, signal.SIGKILL)
        except (ProcessLookupError, OSError):
            pass

    raw_output = b""
    accumulated_text = ""
    prompt_count = 0
    max_prompts = 20
    auth_failed = False

    try:
        while True:
            # Check if child process has exited
            child_pid, status = os.waitpid(pid, os.WNOHANG)
            if child_pid != 0:
                # Process exited
                exit_code = os.waitstatus_to_exitcode(status)
                # Drain remaining output
                while True:
                    r, _, _ = select.select([master], [], [], 0.1)
                    if not r:
                        break
                    try:
                        chunk = os.read(master, 1024)
                        if not chunk:
                            break
                        raw_output += chunk
                    except OSError:
                        break
                output_str = clean_text(raw_output.decode('utf-8', errors='replace'))
                sys.stdout.write(output_str)
                sys.stdout.flush()
                sys.exit(exit_code)

            r, _, _ = select.select([master], [], [], 0.3)
            if not r:
                continue

            try:
                chunk = os.read(master, 1024)
            except OSError:
                # EIO typically means slave was closed
                break

            if not chunk:
                break

            raw_output += chunk
            chunk_str = clean_text(chunk.decode('utf-8', errors='replace'))
            accumulated_text += chunk_str

            if "logincheck" in chunk_str or "Login failed" in chunk_str or "Authentication failed" in chunk_str:
                auth_failed = True

            # Check for prompts in accumulated_text
            # 1. SSL Certificate verification prompt
            cert_match = re.search(r"Enter 'yes' to accept, 'no' to abort; anything else to view:\s*$", accumulated_text)
            if not cert_match:
                cert_match = re.search(r"Certificate.*failed verification.*?Enter 'yes' to accept.*?:\s*$", accumulated_text, re.DOTALL)

            if cert_match:
                prompt_count += 1
                cert_details = accumulated_text.strip()
                fail_idx = cert_details.find("Server certificate verify failed")
                if fail_idx == -1:
                    fail_idx = cert_details.find("Certificate from VPN server")
                if fail_idx != -1:
                    cert_msg = cert_details[fail_idx:cert_match.start()].strip()
                else:
                    cert_msg = "The VPN server's SSL certificate could not be verified automatically."

                question = f"{cert_msg}\n\nDo you want to accept this certificate and continue connecting?"
                accepted = dialog_yesno(f"VPN Certificate - {vpn_name}", question)
                if accepted:
                    os.write(master, b"yes\n")
                    accumulated_text = ""
                else:
                    os.write(master, b"no\n")
                    kill_child()
                    sys.exit(130)
                continue

            # 2. Username prompt
            user_match = re.search(r"(?:^|\n)\s*(?:vpn\.user-name|vpn\.secrets\.username|User name|Username)\s*:\s*$", accumulated_text, re.IGNORECASE)
            if user_match:
                prompt_count += 1
                prefix = "Authentication failed. Please try again.\n\n" if auth_failed else ""
                prompt_label = f"{prefix}Enter username for {vpn_name}:"
                auth_failed = False
                ok, username = dialog_input(window_title, prompt_label)
                if ok:
                    os.write(master, (username + "\n").encode('utf-8'))
                    accumulated_text = ""
                else:
                    kill_child()
                    sys.exit(130)
                continue

            # 3. Password / Secret prompt
            pass_match = re.search(r"(?:^|\n)\s*(?:(?:vpn\.secrets\.)?(?:gateway-)?(?:password|passphrase|secret|pin)(?:\s*\([^)]*\))?)\s*:\s*$", accumulated_text, re.IGNORECASE)
            if pass_match:
                prompt_count += 1
                prompt_label = f"Enter password for {vpn_name}:"
                ok, password = dialog_password(window_title, prompt_label)
                if ok:
                    os.write(master, (password + "\n").encode('utf-8'))
                    accumulated_text = ""
                else:
                    kill_child()
                    sys.exit(130)
                continue

            # 4. 2FA / OTP / Token / Challenge prompt
            otp_match = re.search(r"(?:^|\n)\s*(?:challenge|response|passcode|token|otp|one-time password|verification code)\s*:\s*$", accumulated_text, re.IGNORECASE)
            if otp_match:
                prompt_count += 1
                prompt_label = f"Enter verification code / token for {vpn_name}:"
                ok, code = dialog_input(window_title, prompt_label)
                if ok:
                    os.write(master, (code + "\n").encode('utf-8'))
                    accumulated_text = ""
                else:
                    kill_child()
                    sys.exit(130)
                continue

            # 5. Generic fallback prompt: ends with ": " or "? " and no newline
            generic_match = re.search(r"(?:^|\n)\s*([^\n\r]+?)\s*[:\?]\s*$", accumulated_text)
            if generic_match and len(accumulated_text.splitlines()[-1].strip()) < 80:
                line = generic_match.group(1).strip()
                if not line.startswith("http") and not line.startswith("Connected") and not line.startswith("SSL"):
                    prompt_count += 1
                    if any(w in line.lower() for w in ["pass", "secret", "pin", "key"]):
                        ok, val = dialog_password(window_title, f"{line}:")
                    else:
                        ok, val = dialog_input(window_title, f"{line}:")
                    if ok:
                        os.write(master, (val + "\n").encode('utf-8'))
                        accumulated_text = ""
                    else:
                        kill_child()
                        sys.exit(130)
                    continue

            if prompt_count >= max_prompts:
                print("Exceeded maximum authentication attempts.", file=sys.stderr)
                kill_child()
                sys.exit(1)

    except KeyboardInterrupt:
        kill_child()
        sys.exit(130)
    finally:
        try:
            os.close(master)
        except OSError:
            pass

    _, status = os.waitpid(pid, 0)
    exit_code = os.waitstatus_to_exitcode(status)
    sys.exit(exit_code)

if __name__ == '__main__':
    main()
