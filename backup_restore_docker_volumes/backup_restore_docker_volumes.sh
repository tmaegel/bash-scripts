#!/bin/bash

VOLUMES_BACKUP=("data" "db" "apps" "config") # Define your volumes (without VOLUME_PREFIX) here.
BACKUP_DIR="./backup"
VOLUME_PREFIX=""
APP_VERSION_OLD=""
APP_VERSION_NEW=""

function show_usage() {
  printf "\n"
  printf "Update docker app using backup\n"
  printf "Usage:\n"
  printf "%s\n" "  $0 [options [parameters]]"
  printf "Example:\n"
  printf "%s\n" "  $0 --volume-prefix nextcloud --version-old 18 --version-new 19"
  printf "\n"
  printf "Options:\n"
  printf "%s\t%s\t%s\n" "  -vp" "--volume-prefix" "Volume prefix"
  printf "%s\t%s\t%s\n" "  -vo" "--version-old" "Old app major version"
  printf "%s\t%s\t%s\n" "  -vn" "--version-new" "new app major version"
  printf "%s\t%s\t\t%s\n" "  -h" "--help" "Print help"
  printf "\n"

  return 0
}

if [ $# -eq 0 ]; then
  show_usage
  exit 0
fi

while [ -n "$1" ]; do
  case $1 in
    --volume-prefix|-vp)
      shift
      echo "* VOLUME_PREFIX = $1"
      VOLUME_PREFIX="$1"
    ;;
    --version-old|-vo)
      shift
      if [[ "$1" =~ ^[0-9]+$ ]] ; then
          APP_VERSION_OLD="$1"
          echo "* APP_VERSION_OLD = $1"
      else
        echo "ERROR: Option -vo, --version-old isn't a number."
      fi
    ;;
    --version-new|-vn)
      shift
      if [[ "$1" =~ ^[0-9]+$ ]] ; then
          APP_VERSION_NEW="$1"
          echo "* APP_VERSION_NEW = $1"
      else
        echo "ERROR: Option -vn, --version-new isn't a number."
      fi
    ;;
    *)
      echo "ERROR: Invalid option."
      show_usage
      exit 1
    ;;
  esac
  shift
done

if [ -z "$VOLUME_PREFIX" ]; then
  show_usage
  echo "ERROR: Missing -vp, --volume-prefix option."
  exit 1
fi
if [ -z "$APP_VERSION_NEW" ]; then
  show_usage
  echo "ERROR: Missing -vn, --version-new option."
  exit 1
fi

echo "Make sure that you have shut down the container application (e.g. docker-compose down) and the volumes are not used otherwise."
echo "Press [y] to continue or any other key to cancel."
read -r INPUT
if [ "${INPUT,,}" != "y" ]; then
  echo "Cancel."
fi

if [ ! -d "$BACKUP_DIR" ]; then
  mkdir "$BACKUP_DIR"
fi

# Backup the volumes
for VOL in "${VOLUMES_BACKUP[@]}"; do
  echo "Backup data from volume ${VOLUME_PREFIX}_${VOL}"
  if [ -z "$APP_VERSION_OLD" ]; then
    BACKUP_VOL="${VOLUME_PREFIX}_${VOL}"
  else
    BACKUP_VOL="${VOLUME_PREFIX}_${VOL}_${APP_VERSION_OLD}"
  fi
  docker run --rm -v "$BACKUP_VOL:/${VOL}" -v "$(pwd)/backup:/backup" debian tar czf "/backup/${VOL}.tar.gz" "${VOL}"
done

# Restore the volumes
for VOL in "${VOLUMES_BACKUP[@]}"; do
  echo "Restore data to volume ${VOLUME_PREFIX}_${VOL}_${APP_VERSION_NEW}"
  docker run -v "${VOLUME_PREFIX}_${VOL}_${APP_VERSION_NEW}:/${VOL}" --name "container_${VOL}" debian /bin/bash
  docker run --rm --volumes-from "container_${VOL}" -v "$(pwd)/backup:/backup" debian bash -c "cd /${VOL} && tar xf /backup/${VOL}.tar.gz --strip 1"
  docker rm "container_${VOL}" &>/dev/null
done

echo "Backup and restore completed. Now you can update your container application (e.g. docker-compose pull) and start it (e.g docker-compose up -d)"
echo "Make sure you are using the correct volume names."

exit 0
