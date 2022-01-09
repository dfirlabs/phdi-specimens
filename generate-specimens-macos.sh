#!/bin/bash
#
# Script to generate Parallels Hard Disk image test files

EXIT_SUCCESS=0;
EXIT_FAILURE=1;

# Checks the availability of a binary and exits if not available.
#
# Arguments:
#   a string containing the name of the binary
#
assert_availability_binary()
{
	local BINARY=$1;

	which ${BINARY} > /dev/null 2>&1;
	if test $? -ne ${EXIT_SUCCESS};
	then
		echo "Missing binary: ${BINARY}";
		echo "";

		exit ${EXIT_FAILURE};
	fi
}

create_test_file_entries()
{
	MOUNT_POINT=$1;

	# Create an empty file
	touch ${MOUNT_POINT}/emptyfile

	# Create a directory
	mkdir ${MOUNT_POINT}/testdir1

	# Create a file
	echo "My file" > ${MOUNT_POINT}/testdir1/testfile1

	# Create a hard link to a file
	ln ${MOUNT_POINT}/testdir1/testfile1 ${MOUNT_POINT}/file_hardlink1

	# Create a symbolic link to a file
	ln -s ${MOUNT_POINT}/testdir1/testfile1 ${MOUNT_POINT}/file_symboliclink1

	# Create a hard link to a directory
	# ln ${MOUNT_POINT}/testdir1 ${MOUNT_POINT}/directory_hardlink1
	# ln: ${MOUNT_POINT}/testdir1: Is a directory

	# Create a symbolic link to a directory
	ln -s ${MOUNT_POINT}/testdir1 ${MOUNT_POINT}/directory_symboliclink1

	# Create a file with an UTF-8 NFC encoded filename
	touch `printf "${MOUNT_POINT}/nfc_t\xc3\xa9stfil\xc3\xa8"`

	# Create a file with an UTF-8 NFD encoded filename
	touch `printf "${MOUNT_POINT}/nfd_te\xcc\x81stfile\xcc\x80"`

	# Create a file with an UTF-8 NFD encoded filename
	touch `printf "${MOUNT_POINT}/nfd_\xc2\xbe"`

	# Create a file with an UTF-8 NFKD encoded filename
	touch `printf "${MOUNT_POINT}/nfkd_3\xe2\x81\x844"`

	# Create a file with filename that requires case folding if
	# the file system is case-insensitive
	touch `printf "${MOUNT_POINT}/case_folding_\xc2\xb5"`

	# Create a file with a forward slash in the filename
	touch `printf "${MOUNT_POINT}/forward:slash"`

	# Create a symbolic link to a file with a forward slash in the filename
	ln -s ${MOUNT_POINT}/forward:slash ${MOUNT_POINT}/file_symboliclink2

	# Create a file with a resource fork with content
	touch ${MOUNT_POINT}/testdir1/resourcefork1
	echo "My resource fork" > ${MOUNT_POINT}/testdir1/resourcefork1/..namedfork/rsrc

	# Create a file with an extended attribute with content
	touch ${MOUNT_POINT}/testdir1/xattr1
	xattr -w myxattr1 "My 1st extended attribute" ${MOUNT_POINT}/testdir1/xattr1

	# Create a directory with an extended attribute with content
	mkdir ${MOUNT_POINT}/testdir1/xattr2
	xattr -w myxattr2 "My 2nd extended attribute" ${MOUNT_POINT}/testdir1/xattr2

	# Create a file with an extended attribute that is not stored inline
	read -d "" -n 8192 -r LARGE_XATTR_DATA < LICENSE;
	touch ${MOUNT_POINT}/testdir1/large_xattr
	xattr -w mylargexattr "${LARGE_XATTR_DATA}" ${MOUNT_POINT}/testdir1/large_xattr
}

assert_availability_binary diskutil;
assert_availability_binary hdiutil;
assert_availability_binary sw_vers;
assert_availability_binary prl_disk_tool;

MACOS_VERSION=`sw_vers -productVersion`;

if test -d ${MACOS_VERSION};
then
	echo "Specimens directory: ${MACOS_VERSION} already exists.";

	exit ${EXIT_FAILURE};
fi

SPECIMENS_PATH="specimens/${MACOS_VERSION}";

mkdir -p ${SPECIMENS_PATH};

set -e;

DEVICE_NUMBER=`diskutil list | grep -e '^/dev/disk' | tail -n 1 | sed 's?^/dev/disk??;s? .*$??'`;

VOLUME_DEVICE_NUMBER=$(( ${DEVICE_NUMBER} + 1 ));

# Create raw disk image with a case-insensitive HFS+ file system
IMAGE_NAME="hfsplus";
IMAGE_SIZE="32M";

hdiutil create -fs 'HFS+' -size ${IMAGE_SIZE} -type UDIF -volname TestVolume ${SPECIMENS_PATH}/${IMAGE_NAME};

hdiutil attach ${SPECIMENS_PATH}/${IMAGE_NAME}.dmg;

create_test_file_entries "/Volumes/TestVolume";

hdiutil detach disk${VOLUME_DEVICE_NUMBER};

DMG_IMAGE_PATH="${SPECIMENS_PATH}/${IMAGE_NAME}.dmg";

# Create a plain image
IMAGE_NAME="plain.hdd";

# Note that the size of the plain image must match that of the raw disk image.
prl_disk_tool create --hdd ${SPECIMENS_PATH}/${IMAGE_NAME} --size ${IMAGE_SIZE}

HDS_FILE_PATH=`find ${SPECIMENS_PATH}/${IMAGE_NAME} -iname \*.hds -print`;

mv -f ${DMG_IMAGE_PATH} ${HDS_FILE_PATH};

PLAIN_IMAGE_PATH="${SPECIMENS_PATH}/${IMAGE_NAME}"

# Create an expanding image
IMAGE_NAME="expanding.hdd";

cp -rf ${PLAIN_IMAGE_PATH} ${SPECIMENS_PATH}/${IMAGE_NAME}

prl_disk_tool convert --hdd ${SPECIMENS_PATH}/${IMAGE_NAME} --expanding

EXPANDING_IMAGE_PATH="${SPECIMENS_PATH}/${IMAGE_NAME}"

# Create a split image
IMAGE_NAME="split.hdd";

cp -rf ${PLAIN_IMAGE_PATH} ${SPECIMENS_PATH}/${IMAGE_NAME}

# Note that image size must be > 2G for split to have any effect.
prl_disk_tool convert --hdd ${SPECIMENS_PATH}/${IMAGE_NAME} --split

# Create an encrypted image without salt
IMAGE_NAME="encrypted-no-salt.hdd";

cp -rf ${EXPANDING_IMAGE_PATH} ${SPECIMENS_PATH}/${IMAGE_NAME}

prl_disk_tool encrypt --hdd ${SPECIMENS_PATH}/${IMAGE_NAME} --no-salt

# TODO: Create an encrypted image with salt

# TODO: Create a snapshot

exit ${EXIT_SUCCESS};

