#!/usr/bin/python
# restore volume from the backup image
# Kui.Shi@huawei.com
#
# Usage: rbd_restore.py <NFS_DIR> <backup_image_id>

import argparse
import os
import sys
import time

from cinderclient import client

import pdb
pdb.set_trace()

TIMEOUT = 10

def validate_arg():
    """ validate the arguments

        - check if the backup volume has a specific dir in nfs_dir.
        - return the list of volume path
        - sampl nfs dir structure
          nfs_dir/
            `-- backup_volume
                |-- backup.log
                `-- volume-af33986b-f387-4f98-9a26-fab0d84edca1
                    |-- volume-af33986b-f387-4f98-9a26-fab0d84edca1
                    `-- volume-af33986b-f387-4f98-9a26-fab0d84edca1_snapshot-ae1607f7-c502-4555-bfdb-f846cc50103d
    """

    # get the argument
    parser = argparse.ArgumentParser(
        description='restore volume from the backup image')
    parser.add_argument('--nfs', metavar='nfs_dir', dest='nfs_dir', type=str)
    parser.add_argument('--volume-id', metavar='backup_volume_id', nargs='+')
    args = parser.parse_args()

    # compose the volume backup dir
    backup_volume_dir = os.path.join(os.path.abspath(args.nfs_dir), "backup_volume")
    full_volume_id = map(lambda m: "volume-" + m, args.volume_id)
    valid_volumes = []

    # loop all the volumes to check if the volume backup dir exists
    for vol in full_volume_id:
        backup_path = os.path.join(backup_volume_dir, vol)
        if os.path.exists(os.path.join(backup_path, vol)):
            valid_volumes.append(backup_path)
        else:
            print("the backup volume is not exist: %s" % vol[7:])

    return list(set(valid_volumes))

def wait_for(volume):
    """ wait for volume is available"""

    # update volume status, check if it is available.
    time.sleep(3)
    start = time.time()
    while(volume.status.upper() != "available".upper()):
        try:
            volume = volume.manager.get(volume.id)
        except Exception as e:
            raise e

        time.sleep(1)
        if time.time() - start > TIMEOUT:
            raise Exception

    return volume

def create_volume():
    """ create new volume for restoring """

    OS_USERNAME = os.environ.get('OS_USERNAME', None) or "admin"
    OS_PASSWORD = os.environ.get('OS_PASSWORD', None) or "admin"
    OS_TENANT_NAME = os.environ.get('OS_TENANT_NAME', None) or "admin"
    OS_AUTH_URL = os.environ.get('OS_AUTH_URL', None) or "http://10.1.4.4:5000/v2.0"

    cinder = client.Client('1', OS_USERNAME, OS_PASSWORD, OS_TENANT_NAME, OS_AUTH_URL)

    volume = cinder.volumes.create('1')
    volume = wait_for(volume)

    return volume

def restore_volume(new_volume, backup_volume):
    """ restore the backup volume """

    # get backup image and snapshots
    #full_volume_id = map(lambda m: "volume-" + m, args.volume_id)
    for file in sorted(os.listdir(backup_volume)):
        abs_file = os.path.abspath(os.path.join(backup_volume,file))
        print file, os.path.getctime(abs_file)

    print("restore volume", new_volume, backup_volume)


if __name__ == "__main__":
    valid_backups = validate_arg()
    print("the backup volume exist in %s" % valid_backups)

    for backup_volume in valid_backups:
        new_volume = create_volume()
        restore_volume(new_volume, backup_volume)
