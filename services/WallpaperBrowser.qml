pragma Singleton  
pragma ComponentBehavior: Bound  
  
import qs.modules.common  
import qs.services  
import Quickshell;  
import QtQuick;  
  
/**  
 * A service for interacting with wallpaper APIs (Unsplash and Wallhaven).  
 */  
Singleton {  
    id: root  
    property Component unsplashResponseDataComponent: WallpaperResponseData {}  

    signal tagSuggestion(string query, var suggestions)  
    signal responseFinished()  

    property string unsplashApiToken: KeyringStorage.keyringData?.apiKeys?.wallpapers_unsplash ?? ""
    property string wallhavenApiToken: Config.options.wallhaven?.apiKey ?? ""  
    property string failMessage: Translation.tr("That didn't work. Tips:\n- Check your search query\n- Try different keywords\n- Check your API key under settings")  
    property var responses: []  
    property int runningRequests: 0  
    property var providerList: ["unsplash", "wallhaven"]  
    property var currentProvider: Config.options.wallpapers.service ?? "wallhaven"
    property string currentSortType: Config.options.wallpapers.sort ?? "favourites"
    property bool showAnimeResults: Config.options.wallpapers.showAnimeResults ?? false
    property string similarImageId: ""
    property var currentSearchTags: []
    property var providers: {  
        "system": { "name": Translation.tr("System") },  
        "unsplash": {  
            "name": "Unsplash",  
            "url": "https://unsplash.com",  
            "api": "https://api.unsplash.com/search/photos",            
            "description": Translation.tr("High quality photos from Unsplash"),  
            "mapFunc": (response) => {  
                const items = Array.isArray(response.results) ? response.results : [];
                return items.map(item => ({
                    "id": item.id,  
                    "width": item.width,  
                    "height": item.height,  
                    "aspect_ratio": item.width / item.height,  
                    "tags": item.tags ? item.tags.map(tag => tag.title).join(" ") : (item.alt_description || item.description || "wallpaper"),  
                    "rating": "s",  
                    "is_nsfw": false,  
                    "md5": item.id,  
                    "preview_url": item.urls.small,  
                    "sample_url": item.urls.full,  
                    "file_url": item.urls.full + "&w=1920&h=1080&fit=crop",
                    "file_ext": "jpg",  
                    "source": item.links.html,  
                    "author": item.user.name,  
                    "author_url": item.user.links.html,
                    "color": item.color || ""
                }))
            },  
            "tagSearchTemplate": "https://api.unsplash.com/search/collections",  
            "tagMapFunc": (response) => {  
                return response.results.slice(0, 10).map(item => ({
                    "name": item.title.toLowerCase().replace(/\s+/g, '-'),  
                    "displayName": item.title,  
                    "count": item.total_photos,  
                    "description": item.description || ""  
                }))
            }  
        },  
        "wallhaven": {  
            "name": "Wallhaven",  
            "url": "https://wallhaven.cc",  
            "api": "https://wallhaven.cc/api/v1/search",  
            "description": Translation.tr("Wallpapers | Advanced search with ratios, resolutions, categories, sorting"),  
            "mapFunc": (response) => {
                const data = response?.data
                if (!Array.isArray(data)) {
                    console.log("[Wallpapers] Wallhaven: invalid or missing data field")
                    return []
                }
                console.log("[Wallpapers] Wallhaven found " + data.length + " items")
                return data.map(item => ({
                    "id": item.id,  
                    "width": item.dimension_x || 1920,  
                    "height": item.dimension_y || 1080,  
                    "aspect_ratio": (item.dimension_x || 1920) / (item.dimension_y || 1080),  
                    "tags": item.tags && Array.isArray(item.tags) ? item.tags.map(tag => tag.name).join(" ") : "",  
                    "rating": item.purity === 'sfw' ? 's' : item.purity === 'sketchy' ? 'q' : 'e',  
                    "is_nsfw": item.purity !== 'sfw',  
                    "md5": item.id,  
                    "preview_url": item.thumbs?.original ?? item.path,
                    "sample_url": item.thumbs?.small ?? item.path,
                    "file_url": item.path,  
                    "file_ext": item.file_type ? item.file_type.split('/')[1] : 'jpg',  
                    "source": item.source || "",
                    "color": item.colors[0] || ""  
                }))
            },  
            "tagSearchTemplate": "https://wallhaven.cc/api/v1/search",  
            "tagMapFunc": (response) => {  
                if (!response.data) return []
                return response.data.slice(0, 10).map(item => ({
                    "name": item.tags?.length > 0 ? item.tags[0].name : "",  
                    "count": ""  
                }))
            }  
        }  
    }

    // --- Helpers ---
    function setRequestHeaders(xhr) {
        if (currentProvider === "unsplash") {
            xhr.setRequestHeader("Authorization", "Client-ID " + root.unsplashApiToken)
        } else if (currentProvider === "wallhaven" && root.wallhavenApiToken) {
            xhr.setRequestHeader("X-API-Key", root.wallhavenApiToken)
        }
    }

    function sendRequest(xhr) {
        try {
            setRequestHeaders(xhr)
            xhr.send()
        } catch (error) {
            console.log("[Wallpapers] Could not send request:", error)
        }
    }

    // --- Public API ---
    function setSort(sort) {
        Config.options.wallpapers.sort = sort.toLowerCase()
    }

    function setAnimeResults(show) {
        Config.options.wallpapers.showAnimeResults = show
    }

    function setProvider(provider) {  
        provider = provider.toLowerCase()  
        if (providerList.indexOf(provider) === -1) {
            root.addSystemMessage(Translation.tr("Invalid API provider. Supported: \n- ") + providerList.join("\n- "))
            return
        }
        const sortDefaults = { "unsplash": "relevance", "wallhaven": "favourites" }
        Config.options.wallpapers.service = provider
        root.currentSortType = sortDefaults[provider] ?? "favourites"
        root.addSystemMessage(Translation.tr("Provider set to ") + providers[provider].name)
    }

    function clearResponses() {  
        responses = []  
    }

    function addSystemMessage(message, fileUrl = "") {
        responses = [...responses, root.unsplashResponseDataComponent.createObject(null, {
            "provider": "system",
            "tags": [],
            "page": -1,
            "images": [],
            "message": message,
            "filePath": fileUrl
        })]
    }

    function constructRequestUrl(tags, limit = 20, page = 1, imageId = "") {
        var provider = providers[currentProvider]  
        var params = []
        var tagString = tags.join(" ")

        if (currentProvider === "unsplash") {
            if (tagString.trim().length > 0) params.push("query=" + encodeURIComponent(tagString))
            params.push("per_page=" + Math.min(limit, 30))
            params.push("page=" + page)
            params.push("order_by=" + root.currentSortType)
            params.push("orientation=landscape")
            params.push("client_id=" + encodeURIComponent(root.unsplashApiToken))
        } else if (currentProvider === "wallhaven") {
            if (imageId !== "") {
                params.push("q=like%3A" + imageId)
                params.push("sorting=relevance")
                params.push("page=" + page)
                params.push("order=desc")
                root.similarImageId = imageId
            } else {
                const safeQuery = tagString + " -people -portrait -face"
                if (tagString.trim().length > 0) params.push("q=" + encodeURIComponent(safeQuery))
                params.push("categories=" + (root.showAnimeResults ? "110" : "100"))
                params.push("purity=100")
                params.push("page=" + page)
                params.push("sorting=" + root.currentSortType)
                params.push("atleast=1920x1080")
                root.similarImageId = ""
            }
        }

        var base = provider.api
        return base + (base.indexOf("?") === -1 ? "?" : "&") + params.join("&")
    }

    function moreLikeThisPicture(imageId, page = 1) {
        if (root.currentProvider !== "wallhaven") {
            root.addSystemMessage(Translation.tr("'More like this picture' feature only works with wallhaven service"))
            return
        }
        root.currentSearchTags = [Translation.tr("Similar to ") + imageId]
        makeRequest([], 20, page, imageId)
    }

    function getTags(imageId, callback) {
        if (currentProvider !== "wallhaven") return

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://wallhaven.cc/api/v1/w/" + imageId)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            try {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    var tags = response.data?.tags?.map(tag => tag.name).join(" ") ?? ""
                    if (callback) callback(tags, response.data?.tags ?? [])
                } else {
                    if (callback) callback("", [])
                }
            } catch (e) {
                if (callback) callback("", [])
            }
        }
        sendRequest(xhr)
    }

    function makeRequest(tags, limit = 20, page = 1, imageId = "") {
        if (imageId === "") root.currentSearchTags = tags

        var url = constructRequestUrl(tags, limit, page, imageId)
        console.log("[Wallpapers] Making request to " + url)

        const newResponse = root.unsplashResponseDataComponent.createObject(null, {
            "provider": currentProvider,
            "tags": tags,
            "page": page,
            "images": [],
            "message": ""
        })

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    var response = providers[currentProvider].mapFunc(JSON.parse(xhr.responseText))
                    newResponse.images = response
                    newResponse.message = response.length > 0 ? "" : root.failMessage
                } catch (e) {
                    console.log("[Wallpapers] Failed to parse response: " + e)
                    newResponse.message = root.failMessage
                }
            } else {
                console.log("[Wallpapers] Request failed with status: " + xhr.status)
                newResponse.message = root.failMessage
            }
            root.runningRequests--
            root.responses = [...root.responses, newResponse]
            root.responseFinished()
        }

        root.runningRequests++
        sendRequest(xhr)
    }

    property var currentTagRequest: null
    function triggerTagSearch(query) {
        if (currentTagRequest) currentTagRequest.abort()

        var provider = providers[currentProvider]
        if (!provider.tagSearchTemplate) return

        var url = provider.tagSearchTemplate
        if (currentProvider === "unsplash") {
            url += "?query=" + encodeURIComponent(query) + "&per_page=10"
        } else if (currentProvider === "wallhaven") {
            url += "?q=" + encodeURIComponent(query)
        }

        var xhr = new XMLHttpRequest()
        currentTagRequest = xhr
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            currentTagRequest = null
            if (xhr.status === 200) {
                try {
                    var response = provider.tagMapFunc(JSON.parse(xhr.responseText))
                    root.tagSuggestion(query, response)
                } catch (e) {
                    console.log("[Wallpapers] Failed to parse tag suggestions: " + e)
                }
            } else {
                console.log("[Wallpapers] Tag search failed with status: " + xhr.status)
            }
        }
        sendRequest(xhr)
    }
}
