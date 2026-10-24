import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Thumbnail image. It currently generates to the right place at the right size, but does not handle metadata/maintenance on modification.
 * See Freedesktop's spec: https://specifications.freedesktop.org/thumbnail-spec/thumbnail-spec-latest.html
 */
StyledImage {
    id: root

    property bool generateThumbnail: true
    required property string sourcePath
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)
    property string thumbnailPath: {
        if (sourcePath.length == 0) return;
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

    onSourceSizeChanged: {
        if (!root.generateThumbnail) return;
        thumbnailGeneration.running = false;
        thumbnailGeneration.running = true;
    }
    Process {
        id: thumbnailGeneration
        command: {
            const maxSize = Images.thumbnailSizes[root.thumbnailSizeName];
            const thumbPath = FileUtils.trimFileProtocol(root.thumbnailPath);
            // Paths are passed as positional args ($1..$3), never interpolated into the
            // script, so quotes in file names can neither break nor inject into it.
            // Exit codes: 0 = already cached, 1 = generated, 2 = failed.
            return ["bash", "-c", `
                thumb="$1"; src="$2"; max="$3"
                [ -f "$thumb" ] && exit 0
                tmp="$thumb.$$.tmp.png"
                trap 'kill "$pid" 2>/dev/null; rm -f "$tmp"' EXIT
                magick "$src" -resize "$max"x"$max" "$tmp" & pid=$!
                wait "$pid" && mv "$tmp" "$thumb" && exit 1
                exit 2
            `, "_", thumbPath, root.sourcePath, `${maxSize}`]
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 1) {
                root.source = "";
                root.source = root.thumbnailPath;
            }
        }
    }
}
