#!/bin/bash

# Define your volumes (without VOLUME_PREFIX) here.
# Resulting volume name is e.g.
# PREFIX_VOL_VERSION
# PREFIX=nextcloud, VOL=data, VERSION=19
# e.g. nextcloud_data_19
VOLUMES_BACKUP=("data" "db" "apps" "config")
BACKUP_DIR="./backup"

BACKUP=0
RESTORE=0
VOLUME_PREFIX=""
APP_VERSION_OLD=""
APP_VERSION_NEW=""

function show_usage() {
  printf "Backup and restore docker volumes\n"
  printf "\nUsage:\n"
  printf "%s\n" "  $(basename "$0") [options [parameters]]"
  printf "\nExample: Backup volumes\n"
  printf "%s\n" "  $(basename "$0") --volume-prefix [ PREFIX ] --backup [ VERSION_OLD ]"
  printf "%s\n" "  $(basename "$0") --volume-prefix nextcloud --backup 18"
  printf "\nExample: Restore volumes\n"
  printf "%s\n" "  $(basename "$0") --volume-prefix [ PREFIX ] --restore [ VERSION_NEW ]"
  printf "%s\n" "  $(basename "$0") --volume-prefix nextcloud --restore 19"
  printf "\nExample: Backup and restore volumes\n"
  printf "%s\n" "  $(basename "$0") --volume-prefix [ PREFIX ] --backup [ VERSION_OLD ] --restore [ VERSION_NEW ]"
  printf "%s\n" "  $(basename "$0") --volume-prefix nextcloud --backup 18 --restore 19"
  printf "\n"
  printf "Options:\n"
  printf "%s\t%s\t%s\n" "  -b" "--backup" "Backup volumes from [ VERSION_OLD ]"
  printf "%s\t%s\t%s\n" "  -r" "--restore" "Restore volumes to [ VERSION_NEW ]"
  printf "%s\t%s\t%s\n" "  -vp" "--volume-prefix" "Volume prefix [ PREFIX ]"
  printf "%s\t%s\t\t%s\n" "  -h" "--help" "Print help"
  printf "\n"

  return 0
}

if [ $# -eq 0 ]; then
  show_usage
  exit 0
fi

echo "INFO: Starting."
while [ -n "$1" ]; do
  case $1 in
    --volume-prefix|-vp)
      shift
      echo "* VOLUME_PREFIX = $1"
      VOLUME_PREFIX="$1"
    ;;
    --backup|-b)
      BACKUP=1
      shift
      if [[ "$1" =~ ^[0-9]+$ ]] ; then
          APP_VERSION_OLD="$1"
          echo "* APP_VERSION_OLD = $1"
      else
        show_usage
        echo "ERR: Option -b, --backup isn't a number."
        exit 1
      fi
    ;;
    --restore|-r)
      RESTORE=1
      shift
      if [[ "$1" =~ ^[0-9]+$ ]] ; then
          APP_VERSION_NEW="$1"
          echo "* APP_VERSION_NEW = $1"
      else
        show_usage
        echo "ERR: Option -r, --restore isn't a number."
        exit 1
      fi
    ;;
    *)
      show_usage
      echo "ERR: Invalid option."
      exit 1
    ;;
  esac
  shift
done

if [ -z "$VOLUME_PREFIX" ]; then
  show_usage
  echo "ERR: Missing -vp, --volume-prefix option."
  exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
  mkdir "$BACKUP_DIR"
fi

# Backup the volumes
if [ "$BACKUP" -eq 1 ]; then
  echo "INFO: Make sure that you have shut down the container application (e.g. docker-compose down) and the volumes are not used otherwise."
  echo "Press [y] to continue or any other key to cancel."
  read -r INPUT
  if [ "${INPUT,,}" != "y" ]; then
    echo "Cancel."
  fi
  echo "INFO: Backup ..."
  for VOL in "${VOLUMES_BACKUP[@]}"; do
    BACKUP_VOL="${VOLUME_PREFIX}_${VOL}_${APP_VERSION_OLD}"
    echo "INFO: Backup data from volume ${BACKUP_VOL}"
    docker run --rm -v "$BACKUP_VOL:/${VOL}" -v "$(pwd)/backup:/backup" debian tar czf "/backup/${VOL}.tar.gz" "${VOL}"
  done
  echo "  OK: Backup completed."
else
  echo "INFO: Missing -b, --backup option."
  echo "INFO: Skipping backup."
fi

# Restore the volumes
if [ "$RESTORE" -eq 1 ]; then
  echo "INFO: Check restore files."
  for VOL in "${VOLUMES_BACKUP[@]}"; do
    if ! [ -f "$BACKUP_DIR/$VOL.tar.gz" ]; then
      echo " ERR: Unable to find restore file $BACKUP_DIR/$VOL.tar.gz"
      exit 1
    fi
  done
  echo "INFO: Restore ..."
  for VOL in "${VOLUMES_BACKUP[@]}"; do
    RESTORE_VOL="${VOLUME_PREFIX}_${VOL}_${APP_VERSION_NEW}"
    echo "INFO: Restore data to volume ${RESTORE_VOL}"
    docker run -v "${RESTORE_VOL}:/${VOL}" --name "container_${VOL}" debian /bin/bash
    docker run --rm --volumes-from "container_${VOL}" -v "$(pwd)/backup:/backup" debian bash -c "cd /${VOL} && tar xf /backup/${VOL}.tar.gz --strip 1"
    docker rm "container_${VOL}" &>/dev/null
  done
  echo "  OK: Restore completed."
else
  echo "INFO: Missing -r, --restore option."
  echo "INFO: Skipping restore."
fi

echo "INFO: Now you can update your container application (e.g. docker-compose pull) and start it (e.g docker-compose up -d)"
echo "INFO: Make sure you are using the correct volume names."

exit 0
