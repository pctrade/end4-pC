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
  
    property string unsplashApiToken: KeyringStorage.keyringData.apiKeys.wallpapers_unsplash ?? ""
    property string wallhavenApiToken: Config.options.wallhaven?.apiKey ?? ""  
    property string failMessage: Translation.tr("That didn't work. Tips:\n- Check your search query\n- Try different keywords\n- Check your API key under settings")  
    property var responses: []  
    property int runningRequests: 0  
    property var providerList: ["unsplash", "wallhaven"]  
    property var currentProvider: Config.options.wallpapers.service ?? "wallhaven" // defaulting to wallhaven bc it doesnt require api key

    property string currentSortType: Config.options.wallpapers.sort ?? "favourites" // Options for wallhaven: date_added, relevance, random, views, favourites, toplist // Options for unsplash: relevant, latest
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
                return items.map(item => {  
                    return {  
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
                        "file_url": item.urls.full,  
                        "file_ext": "jpg",  
                        "source": item.links.html,  
                        "author": item.user.name,  
                        "author_url": item.user.links.html,
                        "color": item.color || ""
                    }  
                })  
            },  
            "tagSearchTemplate": "https://api.unsplash.com/search/collections",  
            "tagMapFunc": (response) => {  
                return response.results.slice(0, 10).map(item => {  
                    return {  
                        "name": item.title.toLowerCase().replace(/\s+/g, '-'),  
                        "displayName": item.title,  
                        "count": item.total_photos,  
                        "description": item.description || ""  
                    }  
                })  
            }  
        },  
        "wallhaven": {  
            "name": "Wallhaven",  
            "url": "https://wallhaven.cc",  
            "api": "https://wallhaven.cc/api/v1/search",  
            "description": Translation.tr("Wallpapers | Advanced search with ratios, resolutions, categories, sorting"),  
            "mapFunc": (response) => {  
                console.log("[Wallpapers] Wallhaven response structure: " + JSON.stringify(Object.keys(response)))  
                if (!response.data) {  
                    console.log("[Wallpapers] Wallhaven response has no data field")  
                    return [];  
                }  
                if (!Array.isArray(response.data)) {  
                    console.log("[Wallpapers] Wallhaven response.data is not an array: " + typeof response.data)  
                    return [];  
                }  
                console.log("[Wallpapers] Wallhaven found " + response.data.length + " items")  
                response = response.data  
                return response.map(item => {  
                    return {  
                        "id": item.id,  
                        "width": item.dimension_x || 1920,  
                        "height": item.dimension_y || 1080,  
                        "aspect_ratio": (item.dimension_x || 1920) / (item.dimension_y || 1080),  
                        "tags": item.tags && Array.isArray(item.tags) ? item.tags.map(tag => tag.name).join(" ") : "",  
                        "rating": item.purity === 'sfw' ? 's' : item.purity === 'sketchy' ? 'q' : 'e',  
                        "is_nsfw": item.purity !== 'sfw',  
                        "md5": item.id,  
                        "preview_url": item.thumbs && item.thumbs.original ? item.thumbs.original : item.path,  
                        "sample_url": item.thumbs && item.thumbs.small ? item.thumbs.small : item.path,  
                        "file_url": item.path,  
                        "file_ext": item.file_type ? item.file_type.split('/')[1] : 'jpg',  
                        "source": item.source || "",
                        "color": item.colors[0] || ""  
                    }  
                })  
            },  
            "tagSearchTemplate": "https://wallhaven.cc/api/v1/search",  
            "tagMapFunc": (response) => {  
                if (!response.data) return [];  
                return response.data.slice(0, 10).map(item => {  
                    return {  
                        "name": item.tags && item.tags.length > 0 ? item.tags[0].name : "",  
                        "count": ""  
                    }  
                })  
            }  
        }  
    }  

    function setSort(sort) {
        sort = sort.toLowerCase() 
        Config.options.wallpapers.sort = sort
    }

    function setAnimeResults(show) {
        Config.options.wallpapers.showAnimeResults = show
    }
  
    function setProvider(provider) {  
        provider = provider.toLowerCase()  
        if (providerList.indexOf(provider) !== -1) {  
            Config.options.wallpapers.service = provider
            root.addSystemMessage(Translation.tr("Provider set to ") + providers[provider].name) 
            if (provider === "unsplash") {
                root.currentSortType = "relevance" // default value
            } 
            if (provider === "wallhaven") {
                root.currentSortType = "favourites" // default value
            }
        } else {  
            root.addSystemMessage(Translation.tr("Invalid API provider. Supported: \n- ") + providerList.join("\n- "))  
        }  
    }  
  
    function clearResponses() {  
        responses = []  
    }  
  
    function addSystemMessage(message) {  
        responses = [...responses, root.unsplashResponseDataComponent.createObject(null, {  
            "provider": "system",  
            "tags": [],  
            "page": -1,  
            "images": [],  
            "message": message  
        })]  
    }  

    function addSimilarImageMessage(message, fileUrl) {  
        responses = [...responses, root.unsplashResponseDataComponent.createObject(null, {  
            "provider": "system",  
            "tags": [],  
            "page": -1,  
            "images": [],  
            "message": message,
            "filePath": fileUrl
        })]  
    }  
  
    function constructRequestUrl(tags, limit=20, page=1, imageId="") {
        var provider = providers[currentProvider]  
        var baseUrl = provider.api  
        var url = baseUrl  
        var tagString = tags.join(" ")  
        var params = []  
          
         if (currentProvider === "unsplash") {
             if (tagString.trim().length > 0) {
                 params.push("query=" + encodeURIComponent(tagString))
             }
             params.push("per_page=" + Math.min(limit, 30))
             params.push("page=" + page)
             params.push(`order_by=${root.currentSortType}`)
             params.push("orientation=landscape")
         
             params.push("client_id=" + encodeURIComponent(root.unsplashApiToken))
         }

        else if (currentProvider === "wallhaven") {  
            if (tagString.trim().length > 0 && imageId == "") {  // normal search

                const safeQuery = `${tagString} -people -portrait -face` // filter to not see people and faces
                if (tagString.trim().length > 0) {  
                    params.push("q=" + encodeURIComponent(safeQuery))  
                }  

                if (root.showAnimeResults) {
                    params.push("categories=110")
                } else {
                    params.push("categories=100")
                }
                
                params.push("purity=100")      //swf
                params.push("page=" + page)
                params.push(`sorting=${root.currentSortType}`)
                params.push("atleast=1920x1080")
                root.similarImageId = ""
            }

            if (imageId !== "") { // 'More like this picture' feature
                // console.log("[Wallpapers] Searching for more images like: " + imageId)

                params.push(`q=like%3A${imageId}`) // idk why but api has to be configured like this, learned it in the hard way
                params.push(`sorting=relevance`)
                params.push(`page=${page}`)
                params.push(`order=desc`)
                root.similarImageId = imageId
            }
        }  
          
        if (baseUrl.indexOf("?") === -1) {  
            url += "?" + params.join("&")  
        } else {  
            url += "&" + params.join("&")  
        }  
        return url  
    }  

    function moreLikeThisPicture(imageId, page=1) { // Uses built-in wallhaven's 'More like this picture' feature
        if (root.currentProvider !== "wallhaven") {
            root.addSystemMessage(Translation.tr("'More like this picture' feature only works with wallhaven service"))
            return;
        }
        root.currentSearchTags = [Translation.tr("Similar to ") + imageId]
        makeRequest([], 20, page, imageId)       
    }

    // Not used for now, but could be usefull in the future
    function getTags(imageId, callback) {
        if (currentProvider !== "wallhaven") {
            // console.log("[Wallpapers] getTags only works with wallhaven (for now, unsplash support will be added)")
            // root.addSystemMessage(Translation.tr("getTags only works with wallhaven (for now, unsplash support will be added)"))
            return;
        }
        
        var url = `https://wallhaven.cc/api/v1/w/${imageId}`
        // console.log("[Wallpapers] Fetching tags from " + url)
        
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText)
                    if (response.data && response.data.tags) {
                        var tags = response.data.tags.map(tag => tag.name).join(" ")
                        // console.log("[Wallpapers] Tags for " + imageId + ": " + tags)
                        
                        if (callback && typeof callback === "function") {
                            callback(tags, response.data.tags)
                        }
                    }
                } catch (e) {
                    // console.log("[Wallpapers] Failed to parse tags response: " + e)
                    if (callback && typeof callback === "function") {
                        callback("", [])
                    }
                }
            }
            else if (xhr.readyState === XMLHttpRequest.DONE) {
                // console.log("[Wallpapers] getTags failed with status: " + xhr.status)
                if (callback && typeof callback === "function") {
                    callback("", [])
                }
            }
        }
        
        try {
            if (root.wallhavenApiToken) {
                xhr.setRequestHeader("X-API-Key", root.wallhavenApiToken)
            }
            xhr.send()
        } catch (error) {
            // console.log("[Wallpapers] Could not fetch tags:", error)
            if (callback && typeof callback === "function") {
                callback("", [])
            }
        }
    }
  
    function makeRequest(tags, limit=20, page=1, imageId="") { // image id is used for "more like this" feature
        if (imageId === "") {
            root.currentSearchTags = tags;
        }
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
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {  
                try {  
                    const provider = providers[currentProvider]  
                    let response = JSON.parse(xhr.responseText)  
                    response = provider.mapFunc(response)  

                    /* if (currentProvider === "wallhaven") { // can be used to set a limit to wallhaven (currently there is not), but not using it as it breaks the page sync
                        response = response.slice(0, limit)
                    } */

                    newResponse.images = response  
                    newResponse.message = response.length > 0 ? "" : root.failMessage  
                      
                } catch (e) {  
                    console.log("[Wallpapers] Failed to parse response: " + e)  
                    newResponse.message = root.failMessage  
                } finally {  
                    root.runningRequests--;  
                    root.responses = [...root.responses, newResponse]  
                }  
            }  
            else if (xhr.readyState === XMLHttpRequest.DONE) {  
                console.log("[Wallpapers] Request failed with status: " + xhr.status)  
                newResponse.message = root.failMessage  
                root.runningRequests--;  
                root.responses = [...root.responses, newResponse]  
            }  
            root.responseFinished()  
        }  
  
        try {  
            if (currentProvider === "unsplash") {  
                xhr.setRequestHeader("Authorization", "Client-ID " + root.unsplashApiToken)  
            } else if (currentProvider === "wallhaven" && root.wallhavenApiToken) {  
                xhr.setRequestHeader("X-API-Key", root.wallhavenApiToken)  
            }  
            root.runningRequests++;  
            xhr.send()  
        } catch (error) {  
            console.log("Could not set headers:", error)  
        }     
    }  
  
    property var currentTagRequest: null  
    function triggerTagSearch(query) {  
        if (currentTagRequest) {  
            currentTagRequest.abort();  
        }  
  
        var provider = providers[currentProvider]  
        if (!provider.tagSearchTemplate) {  
            return  
        }  
          
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
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {  
                currentTagRequest = null  
                try {  
                    var response = JSON.parse(xhr.responseText)  
                    response = provider.tagMapFunc(response)  
                    root.tagSuggestion(query, response)  
                } catch (e) {  
                    console.log("[Wallpapers] Failed to parse tag suggestions: " + e)  
                }  
            }  
            else if (xhr.readyState === XMLHttpRequest.DONE) {  
                console.log("[Wallpapers] Tag search failed with status: " + xhr.status)  
            }  
        }  
  
        try {  
            if (currentProvider === "unsplash") {  
                xhr.setRequestHeader("Authorization", "Client-ID " + root.unsplashApiToken)  
            } else if (currentProvider === "wallhaven" && root.wallhavenApiToken) {  
                xhr.setRequestHeader("X-API-Key", root.wallhavenApiToken)  
            }  
            xhr.send()  
        } catch (error) {  
            console.log("Could not set headers:", error)  
        }     
    }  
}