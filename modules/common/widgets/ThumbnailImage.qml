import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Thumbnail image.
 * Uses system Freedesktop thumbnails or generates them on-demand if missing.
 */
StyledImage {
    id: root

    property bool generateThumbnail: true
    required property string sourcePath
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)
    property string thumbnailPath: {
        if (!sourcePath || sourcePath.length == 0) return "";
        const resolvedUrlWithoutFileProtocol = FileUtils.trimFileProtocol(`${Qt.resolvedUrl(sourcePath)}`);
        const encodedUrlWithoutFileProtocol = resolvedUrlWithoutFileProtocol.split("/").map(part => encodeURIComponent(part)).join("/");
        const md5Hash = Qt.md5(`file://${encodedUrlWithoutFileProtocol}`);
        return `${Directories.genericCache}/thumbnails/${thumbnailSizeName}/${md5Hash}.png`;
    }
    source: thumbnailPath

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    onStatusChanged: {
        if (status === Image.Error && root.generateThumbnail && sourcePath.length > 0) {
            thumbnailGeneration.running = false;
            thumbnailGeneration.running = true;
        }
    }

    onSourceSizeChanged: {
        if (!root.generateThumbnail) return;
        thumbnailGeneration.running = false;
        thumbnailGeneration.running = true;
    }

    Process {
        id: thumbnailGeneration
        command: {
            const maxSize = Images.thumbnailSizes[root.thumbnailSizeName] || 256;
            const thumbPath = FileUtils.trimFileProtocol(root.thumbnailPath);
            return ["bash", "-c", `
                thumb="$1"; src="$2"; max="$3"
                [ -f "$thumb" ] && exit 0
                mkdir -p "$(dirname "$thumb")"
                tmp="$thumb.$$.tmp.png"
                trap 'kill "$pid" 2>/dev/null; rm -f "$tmp"' EXIT
                case "\${src,,}" in
                    *.mp4|*.webm|*.mkv|*.avi|*.mov)
                        if command -v ffmpegthumbnailer &>/dev/null; then
                            ffmpegthumbnailer -i "$src" -o "$tmp" -s "$max" -q 8 2>/dev/null & pid=$!
                        else
                            ffmpeg -y -i "$src" -ss 00:00:01 -vframes 1 -vf "scale=$max:-1" "$tmp" 2>/dev/null & pid=$!
                        fi
                        ;;
                    *)
                        magick "$src" -resize "$max"x"$max" "$tmp" & pid=$!
                        ;;
                esac
                wait "$pid" && mv "$tmp" "$thumb" && exit 1
                exit 2
            `, "_", thumbPath, root.sourcePath, `${maxSize}`]
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 1 || exitCode === 0) {
                root.source = "";
                root.source = root.thumbnailPath;
            }
        }
    }
}
