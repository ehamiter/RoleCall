Title: Plex API Documentation

URL Source: https://www.plexopedia.com/plex-media-server/api/

Published Time: 2025-06-27T13:27:57+00:00

Markdown Content:
Plex API Documentation - Plexopedia

===============

*   [Plexopedia](https://www.plexopedia.com/)
*   [](https://www.plexopedia.com/plex-media-server/api/# "Plexopedia Navigation Menu")

*   [Plex Media Server](https://www.plexopedia.com/plex-media-server/)
    *   ##### [Back](https://www.plexopedia.com/plex-media-server/api/#)

    *   [Plex Media Server](https://www.plexopedia.com/plex-media-server/)
    *   [General](https://www.plexopedia.com/plex-media-server/general/)
    *   [Windows](https://www.plexopedia.com/plex-media-server/windows/)
    *   [API](https://www.plexopedia.com/plex-media-server/api/)
    *   [Plex.tv API](https://www.plexopedia.com/plex-media-server/api-plextv/)

*   [Plex Apps](https://www.plexopedia.com/plex-apps/)
    *   ##### [Back](https://www.plexopedia.com/plex-media-server/api/#)

    *   [Plex Apps](https://www.plexopedia.com/plex-apps/)
    *   [Android](https://www.plexopedia.com/plex-apps/android/)
    *   [Windows](https://www.plexopedia.com/plex-apps/windows/)

*   [Blog](https://www.plexopedia.com/blog/)

*   [My Plex Media Server](https://www.plexopedia.com/plex-server/)

*   [About](https://www.plexopedia.com/about/)
    *   ##### [Back](https://www.plexopedia.com/plex-media-server/api/#)

    *   [About](https://www.plexopedia.com/about/)
    *   [Paul Salmon](https://www.plexopedia.com/about/paul-salmon/)

*   [Search](https://www.plexopedia.com/search/)

*   [Contact](https://www.plexopedia.com/contact/)

*   [Home](https://www.plexopedia.com/)
*   >[plex media server](https://www.plexopedia.com/plex-media-server/)
*   >API

Plex API Documentation
======================

Plex Media Server contains a large number of API commands that can be sent as requests to the Plex server. These commands can allow a Plex owner to gather information about their Plex server, download the [Plex database](https://www.plexopedia.com/plex-media-server/general/plex-database-location/) or logs, and even manage the updates of the Plex server software.

Looking for an API command?
---------------------------

You can use the expandable menu on the left to view a specific API command you can use with your own Plex sever.

Below is a list of commands added recently as well as some of the most popular ones over the past month.

What's new
----------

*   [Plex.tv - Change Discover Together Settings](https://www.plexopedia.com/plex-media-server/api-plextv/discover-together/)
*   [Plex.tv - Change Sync My Watch State and Ratings](https://www.plexopedia.com/plex-media-server/api-plextv/sync-watch-state-ratings/)
*   [Plex.tv - Change Opt-Out Settings](https://www.plexopedia.com/plex-media-server/api-plextv/opt-outs-settings-change/)
*   [Set a Server Preference](https://www.plexopedia.com/plex-media-server/api/server/preference-set/)

What's popular
--------------

*   [Get All Movies](https://www.plexopedia.com/plex-media-server/api/library/movies/)
*   [Get Libraries](https://www.plexopedia.com/plex-media-server/api/server/libraries/)
*   [Download Media File](https://www.plexopedia.com/plex-media-server/api/library/download-media-file/)
*   [Server Identity](https://www.plexopedia.com/plex-media-server/api/server/identity/)

Using the API commands
----------------------

The API commands can be run from any Web browser, or from tools that can make GET HTTP requests, such as [Postman](https://www.postman.com/). Most requests sent to Plex will return an XML string value that can then be parsed to obtain the information needed from the request.

All requests do require a [Plex token](https://www.plexopedia.com/plex-media-server/general/plex-token/) to be submitted. The owner of the Plex server can easily obtain the Plex token from the server, and then add it to any API request for authentication.

Documentation organization
--------------------------

This API is organized into various categories to help sort the API requests that can be sent to a Plex server. I have tried to provide as much documentation about each request as I could, however, there is sometimes limited information about the return data from an API request.

In addition, I will continue to add more API commands to this site as I am able to find and report the commands.

The current API commands that are available on this site can be found in the list on the left side. The commands are organized into various sections to make finding the correct API command easier.

The Plex token
--------------

Most Plex API commands will require a [Plex token](https://www.plexopedia.com/plex-media-server/general/plex-token/) to be passed in as a parameter. Most commands will require the Plex administrative token. Other commands, such as playlists, are specific to a Plex user and will require the [token for the user](https://www.plexopedia.com/plex-media-server/general/plex-token/#getcurrentusertoken).

Providing an invalid token, or a token that doesn't have correct access to make the request, will result in HTTP error `401 - Unauthorized`.

JSON response
-------------

By default, Plex will return XML data for those API requests that return a response with data. This is what is described on the pages of the API commands.

Plex also can return a response in JSON format if you wish to work with JSON.

To have Plex return JSON, you simply add the following header to the API request:

Accept: application/json

[API Home](https://www.plexopedia.com/plex-media-server/api/)[Plex.tv API Home](https://www.plexopedia.com/plex-media-server/api-plextv/)
### Server

[Server Capabilities](https://www.plexopedia.com/plex-media-server/api/server/capabilities/)[Server Identity](https://www.plexopedia.com/plex-media-server/api/server/identity/)[Get Server Preferences](https://www.plexopedia.com/plex-media-server/api/server/preferences/)[Set a Server Preference](https://www.plexopedia.com/plex-media-server/api/server/preference-set/)[Get Server List](https://www.plexopedia.com/plex-media-server/api/server/list/)[Get Accounts](https://www.plexopedia.com/plex-media-server/api/server/accounts/)[Get a Single Account](https://www.plexopedia.com/plex-media-server/api/server/account/)[Get Devices](https://www.plexopedia.com/plex-media-server/api/server/devices/)[Get a Single Device](https://www.plexopedia.com/plex-media-server/api/server/device/)[Get All Activities](https://www.plexopedia.com/plex-media-server/api/server/activities/)[Stop an Activity](https://www.plexopedia.com/plex-media-server/api/server/stop-activity/)[Get Transient Token](https://www.plexopedia.com/plex-media-server/api/server/transient-token/)[Perform Search](https://www.plexopedia.com/plex-media-server/api/server/search/)[Listen for Notifications](https://www.plexopedia.com/plex-media-server/api/server/listen-notifications/)[Listen for Events](https://www.plexopedia.com/plex-media-server/api/server/listen-events/)[Check for Updates](https://www.plexopedia.com/plex-media-server/api/server/update-check/)[Get Update Status](https://www.plexopedia.com/plex-media-server/api/server/update-status/)

### Sessions

[Get Active Sessions](https://www.plexopedia.com/plex-media-server/api/server/sessions/)[Get Transcode Sessions](https://www.plexopedia.com/plex-media-server/api/server/transcode-sessions/)[Terminate a Session](https://www.plexopedia.com/plex-media-server/api/server/session-terminate/)[Terminate a Transcode Session](https://www.plexopedia.com/plex-media-server/api/server/session-transcode-terminate/)[Get Session History](https://www.plexopedia.com/plex-media-server/api/server/session-history/)

### Library

[Get Libraries](https://www.plexopedia.com/plex-media-server/api/server/libraries/)[Get Library Details](https://www.plexopedia.com/plex-media-server/api/library/details/)[Add a Library](https://www.plexopedia.com/plex-media-server/api/library/add/)[Delete a Library](https://www.plexopedia.com/plex-media-server/api/server/library-delete/)[Scan All Libraries](https://www.plexopedia.com/plex-media-server/api/library/scan/)[Scan a Single Library](https://www.plexopedia.com/plex-media-server/api/library/scan-single/)[Scan a Partial Library](https://www.plexopedia.com/plex-media-server/api/library/scan-partial/)[Refresh Metadata for a Library](https://www.plexopedia.com/plex-media-server/api/library/refresh-metadata/)

### Media

[Get Recently Added Media](https://www.plexopedia.com/plex-media-server/api/library/recently-added/)[Mark Item as Watched](https://www.plexopedia.com/plex-media-server/api/library/media-mark-watched/)[Mark Item as Unwatched](https://www.plexopedia.com/plex-media-server/api/library/media-mark-unwatched/)[Search for Match](https://www.plexopedia.com/plex-media-server/api/library/search-match/)[Download Media File](https://www.plexopedia.com/plex-media-server/api/library/download-media-file/)[Update Play Progress](https://www.plexopedia.com/plex-media-server/api/server/update-media-progress/)

### Movies

[Get All Movies](https://www.plexopedia.com/plex-media-server/api/library/movies/)[Get a Movie](https://www.plexopedia.com/plex-media-server/api/library/movie/)[Update a Movie](https://www.plexopedia.com/plex-media-server/api/library/movie-update/)[Update a Movie Using Match](https://www.plexopedia.com/plex-media-server/api/library/movie-update-match/)[Delete a Movie](https://www.plexopedia.com/plex-media-server/api/library/movie-delete/)[Get Newest Movies](https://www.plexopedia.com/plex-media-server/api/library/movies-newest/)[Get Recently Added Movies](https://www.plexopedia.com/plex-media-server/api/library/movies-recently-added/)[Get Recently Viewed Movies](https://www.plexopedia.com/plex-media-server/api/library/movies-recently-viewed/)[Get On Deck Movies](https://www.plexopedia.com/plex-media-server/api/library/movies-on-deck/)[Get All Movies for a Resolution](https://www.plexopedia.com/plex-media-server/api/library/movies-resolution/)[Get All Movies for a Decade](https://www.plexopedia.com/plex-media-server/api/library/movies-decade/)[Get All Unwatched Movies for a User](https://www.plexopedia.com/plex-media-server/api/library/movies-unwatched/)[Get a Movie's Poster](https://www.plexopedia.com/plex-media-server/api/library/movie-poster/)[Get a Movie's Background](https://www.plexopedia.com/plex-media-server/api/library/movie-background/)

### TV Shows

[Get All TV Shows](https://www.plexopedia.com/plex-media-server/api/library/tvshows/)[Get All TV Show Seasons](https://www.plexopedia.com/plex-media-server/api/library/tvshows-seasons/)[Update a TV Show Series Using Match](https://www.plexopedia.com/plex-media-server/api/library/tvshow-update-match/)[Get All TV Show Episodes](https://www.plexopedia.com/plex-media-server/api/library/tvshows-episodes/)[Get Recently Added TV Shows](https://www.plexopedia.com/plex-media-server/api/library/tvshows-recently-added/)

### Music

[Get All Music Artists](https://www.plexopedia.com/plex-media-server/api/library/music/)[Get All Music Albums for an Artist](https://www.plexopedia.com/plex-media-server/api/library/music-albums-artist/)[Get All Tracks for a Music Album](https://www.plexopedia.com/plex-media-server/api/library/music-albums-tracks/)[Update Music Artist Details Using Match](https://www.plexopedia.com/plex-media-server/api/library/music-artist-update-match/)[Update Music Album Details Using Match](https://www.plexopedia.com/plex-media-server/api/library/music-album-update-match/)

### Photos

[Get All Photos](https://www.plexopedia.com/plex-media-server/api/library/photos/)[Add a Photo to Favorites](https://www.plexopedia.com/plex-media-server/api/library/photo-favorites-add/)

### Other Videos

[Get All Videos](https://www.plexopedia.com/plex-media-server/api/library/videos/)

### Playlists

[Get All Playlists](https://www.plexopedia.com/plex-media-server/api/playlists/view/)[Get a Playlist](https://www.plexopedia.com/plex-media-server/api/playlists/view-single/)[Create a Playlist](https://www.plexopedia.com/plex-media-server/api/playlists/create/)[Update a Playlist](https://www.plexopedia.com/plex-media-server/api/playlists/update/)[Delete a Playlist](https://www.plexopedia.com/plex-media-server/api/playlists/delete/)[Get Items in a Playlist](https://www.plexopedia.com/plex-media-server/api/playlists/view-items/)[Add an Item to a Playlist](https://www.plexopedia.com/plex-media-server/api/playlists/add-item/)[Delete an Item from a Playlist](https://www.plexopedia.com/plex-media-server/api/playlists/delete-item/)[Delete All Items from a Playlist](https://www.plexopedia.com/plex-media-server/api/playlists/delete-items/)

### Maintenance

[Empty Trash](https://www.plexopedia.com/plex-media-server/api/library/empty-trash/)[Clean Bundles](https://www.plexopedia.com/plex-media-server/api/library/clean-bundles/)[Optimize Database](https://www.plexopedia.com/plex-media-server/api/library/optimize-database/)

### Scheduled Tasks

[Get All Scheduled Tasks](https://www.plexopedia.com/plex-media-server/api/server/scheduled-tasks/)[Run All Scheduled Tasks](https://www.plexopedia.com/plex-media-server/api/server/task-run-all/)[Stop All Scheduled Tasks](https://www.plexopedia.com/plex-media-server/api/server/task-stop-all/)[Run Backup Database Task](https://www.plexopedia.com/plex-media-server/api/server/task-backup-database/)[Stop Backup Database Task](https://www.plexopedia.com/plex-media-server/api/server/task-backup-database-stop/)[Run Optimize Database Task](https://www.plexopedia.com/plex-media-server/api/server/task-optimize-database/)[Stop Optimize Database Task](https://www.plexopedia.com/plex-media-server/api/server/task-optimize-database-stop/)[Run Clean Old Bundles Task](https://www.plexopedia.com/plex-media-server/api/server/task-clean-old-bundles/)[Stop Clean Old Bundles Task](https://www.plexopedia.com/plex-media-server/api/server/task-clean-old-bundles-stop/)[Run Clean Old Cache Files Task](https://www.plexopedia.com/plex-media-server/api/server/task-clean-old-cache-files/)[Stop Clean Old Cache Files Task](https://www.plexopedia.com/plex-media-server/api/server/task-clean-old-cache-files-stop/)[Run Refresh Local Metadata Task](https://www.plexopedia.com/plex-media-server/api/server/task-refresh-local-metadata/)[Stop Refresh Local Metadata Task](https://www.plexopedia.com/plex-media-server/api/server/task-refresh-local-metadata-stop/)[Run Refresh Libraries Task](https://www.plexopedia.com/plex-media-server/api/server/task-refresh-libraries/)[Stop Refresh Libraries Task](https://www.plexopedia.com/plex-media-server/api/server/task-refresh-libraries-stop/)[Run Extensive Media Analysis Task](https://www.plexopedia.com/plex-media-server/api/server/task-extensive-media-analysis/)[Stop Extensive Media Analysis Task](https://www.plexopedia.com/plex-media-server/api/server/task-extensive-media-analysis-stop/)[Run Refresh Metadata Periodically Task](https://www.plexopedia.com/plex-media-server/api/server/task-refresh-metadata-periodically/)[Stop Refresh Metadata Periodically Task](https://www.plexopedia.com/plex-media-server/api/server/task-refresh-metadata-periodically-stop/)[Run Upgrade Media Analysis Task](https://www.plexopedia.com/plex-media-server/api/server/task-upgrade-media-analysis/)[Stop Upgrade Media Analysis Task](https://www.plexopedia.com/plex-media-server/api/server/task-upgrade-media-analysis-stop/)

### Troubleshooting

[Log a Single Message](https://www.plexopedia.com/plex-media-server/api/server/log-single/)[Log Multiple Messages](https://www.plexopedia.com/plex-media-server/api/server/log-multiple/)[Download Databases](https://www.plexopedia.com/plex-media-server/api/server/download-databases/)[Download Logs](https://www.plexopedia.com/plex-media-server/api/server/download-logs/)

### Reference

[Arrays](https://www.plexopedia.com/plex-media-server/api/arrays/)[Filtering](https://www.plexopedia.com/plex-media-server/api/filter/)

[↑](https://www.plexopedia.com/plex-media-server/api/#top-of-page)

##### Connect with Plexopedia!

*   [](https://www.facebook.com/plexopedia/ "Follow Plexopedia on Facebook")
*   [](https://www.instagram.com/plexopedia/ "Follow Plexopedia on Instagram")
*   [](https://www.pinterest.com/Plexopedia/ "Follow Plexopedia on Pinterest")

Copyright ©2025 Plexopedia.

[Privacy Policy](https://www.plexopedia.com/privacy-policy/)
