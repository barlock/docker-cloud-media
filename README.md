# Usage

Default settings use ~100GB for local media, and Plexdrive chunks and cache are removed after 24 hours:
```
docker create \
	--name cloud-media \
	-v /media:/local-media:shared \
	-v /mnt/external/media:/local-union:shared \
	-v /configurations:/config \
	-v /mnt/external/plexdrive:/chunks \
	-v /logs:/log \
	-e ROOT_NODE_ID="<GDRIVE_ROOT_NODE>" \
	-e ENCFS_PASSWORD="<ENCFS_CONFIG_PASSWORD>" \
	--privileged --cap-add=MKNOD --cap-add=SYS_ADMIN --device=/dev/fuse \
	barlock/cloud-media
```

# Parameters
The parameters are split into two halves, separated by a colon, the left hand side representing the host and the right the container side.
For example with a volume `-v external:internal` - what this shows is the volume mapping from internal to external of the container.
Example `-v /media:/local-media` would expose directory **/local-media** from inside the container to be accessible from the host's directory **/media**.

OBS: Some of the volumes need to have **:shared** appended to it for it to work. This is needed to have the files visible for the host.
Example `-v /media:/local-media:shared`.

**:shared** is also needed on if you mount these folders to your other Docker containers.

Volumes:
* `-v /local-media` - Local files stored on disk - Append :shared
* `-v /local-decrypt` - Union of all files stored on cloud and local - Append **:shared**
* `-v /config` - Rclone and plexdrive configurations
* `-v /chunks` - Plexdrive cache chunks
* `-v /data/db` - MongoDB database
* `-v /log` - Log files from mount, cloudupload and rmlocal
* `-v /cloud-encrypt` - Cloud files encrypted synced with Plexdrive. - Append **:shared**
* `-v /cloud-decrypt` - Cloud files decrypted with Rclone - Append **:shared**

Environment variables:
* `-e LOCAL_DRIVE` - Turn off support for the local drive, this disables the union and encrypting it. "0" will disable local drive support (default **"1"**) 
* `-e REMOTE_DRIVE` - Turn off support for the remote drive, this disables the union and decrypting it. "0" will disable remote drive support (default **"1"**)
* `-e REMOTE_PROVIDED` - Use this if you mount an encrypted remote drive yourself. This isn't effective if `REMOTE_DRIVE = "0"`. You will need to mount your own remote into `/cloud-encrypt` (default **"0"**)
* `-e CHUNK_SIZE` - Plexdrive: The size of each chunk that is downloaded (default **10M**)
* `-e CLEAR_CHUNK_MAX_SIZE` - Plexdrive: The maximum size of the temporary chunk directory (empty as default)
* `-e CLEAR_CHUNK_AGE` - Plexdrive: The maximum age of a cached chunk file (default **24h**) - this is ignored if `CLEAR_CHUNK_MAX_SIZE` is set
* `-e MONGO_DATABASE` - Mongo database used for Plexdrive (default **plexdrive**)
* `-e DATE_FORMAT` - Date format for loggin (default **+%F@%T**)
* `-e PGID` Group id
* `-e PUID` User id


`--privileged --cap-add=MKNOD --cap-add=SYS_ADMIN --device=/dev/fuse` must be there for fuse to work within the container.

# Setup
After the docker image has been setup and running, Plexdrive needs to be configured.

## Plexdrive
Setup Plexdrive to the cloud. Run the command `docker exec -ti <DOCKER_CONTAINER> plexdrive_setup`

Plexdrive documentation if needed [click here](https://github.com/dweidenfeld/plexdrive/tree/4.0.0)

# Commands
Check if everything is running `docker exec <DOCKER_CONTAINER> check`


# How this works?
Following services are used to sync, encrypt/decrypt and mount media:
 - Plexdrive
 - encfs
 - UnionFS

When using encryption this gives us a total of 5 directories:
 - /cloud-encrypt: Cloud data encrypted (Mounted with Plexdrive)
 - /cloud-decrypt: Cloud data decrypted (Mounted with encfs)
 - /local-decrypt: Local data decrypted that is yet to be uploaded to the cloud
 - /chunks: Plexdrive temporary files and caching
 - /local-media: Union of decrypted cloud data and local data (Mounted with Union-FS)

When NOT using encryption this gives us a total of 4 directories:
 - /cloud-decrypt: Cloud data decrypted (Mounted with Plexdrive)
 - /local-decrypt: Local data decrypted that is yet to be uploaded to the cloud
 - /chunks: Plexdrive temporary files and caching
 - /local-media: Union of decrypted cloud data and local data (Mounted with Union-FS)


All Cloud data is mounted to `/cloud-encrypt`. This folder is then decrypted and mounted to `/cloud-decrypt`.
d
A local folder (`/local-decrypt`) containing local media that is yet to be uploaded to the cloud.
`/local-decrypt` and `/cloud-decrypt` is then mounted to a third folder (`/local-media`) with certain permissions - `/local-decrypt` with Read/Write permissions and `/cloud-decrypt` with Read-only permission.

Everytime new media is retrieved it should be added to `/local-media`. By adding files to `/local-media` it is added to `/local-decrypt` because of the Read/Write permissions. That is why a cronjob is needed to upload local files from `/local-decrypt`.

By having a cronjob to rmlocal it will sooner or later move media from `/local-decrypt` depending on the `REMOVE_LOCAL_FILES_BASED_ON` setting. Media is only removed from `/local-decrypt` and still appears in `/local-media` because it is still be accessable from the cloud.

If `REMOVE_LOCAL_FILES_BASED_ON` is set to **space** it will only remove content (if local media size has exceeded `REMOVE_LOCAL_FILES_WHEN_SPACE_EXCEEDS_GB`) starting from the oldest accessed file and will only free up atleast `FREEUP_ATLEAST_GB`. If **time** is set it will only remove files older than `REMOVE_LOCAL_FILES_AFTER_DAYS`. If **instant** is set it will remove all files when running.

*Media is never deleted locally before being uploaded successful to the cloud.*

![UML diagram](uml.png)

## Plexdrive
Plexdrive 4.0.0 is currently used and tested.

Plexdrive is used to mount Google Drive to a local folder (`/cloud-encrypt`).

Plexdrive create two files in `/config`: `config.json` and `token.json`. These are used to store Google Drive api keys.

## UnionFS
UnionFS is used to mount both cloud and local media to a local folder (`/local-media`).

 - Cloud storage `/cloud-decrypt` is mounted with Read-only permissions.
 - Local storage `/local-decrypt` is mounted with Read/Write permissions.

The reason for these permissions are that when writing to the local folder (`/local-media`) it will not try to write it directly to the cloud storage `/cloud-decrypt`, but instead to the local storage (`/local-decrypt`). Later this will be encrypted and uploaded to the cloud by Rclone.


# Build Dockerfile
## Build
`docker build -t cloud-media .`

## Test run
`docker run --name cloud-media -d cloud-media`
