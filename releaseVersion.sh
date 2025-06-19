#!/bin/bash -e

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ ! "$BRANCH" = "master" ]; then
	printf >&2 "\033[1;31mNot on master branch, performing a dry run\033[0m\n"
	DRY_RUN="1"
else 
	if [ "$1" = "--dry" ]; then
		DRY_RUN=$1
	fi
fi

if [ ! -z "$DRY_RUN" ]; then
	printf >&2 "\033[1;31mPerforming a dry run\033[0m\n"
fi

echo -e "\033[1;34mBuilding archive and exporting\033[0m"

ARCHIVE=Distribution/Archive.xcarchive
EXPORT_DIR=Distribution/Export

rm -fr Distribution
mkdir -p Distribution

export CODE_SIGNING_REQUIRED=NO && xcodebuild -project EPSpy.xcodeproj -scheme "EPSpy" -configuration release clean archive -archivePath "${ARCHIVE}"
mkdir -p "${EXPORT_DIR}"
cp -R "${ARCHIVE}"/Products/Applications/EPSpy.app "${EXPORT_DIR}"/EPSpy.app

SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${EXPORT_DIR}"/*.app/Contents/Info.plist)
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${EXPORT_DIR}"/*.app/Contents/Info.plist)

VERSION="${SHORT_VERSION}"."${BUILD_NUMBER}"

ZIP_FILE=Distribution/EPSpy.zip

echo -e "\033[1;34mVersion is: $VERSION\033[0m"

echo -e "\033[1;34mCreating ZIP file\033[0m"

ditto -c -k --sequesterRsrc --keepParent "${EXPORT_DIR}"/*.app "${ZIP_FILE}" &> /dev/null

if [ -z "$DRY_RUN" ]; then
	echo -e "\033[1;34mCreating a GitHub release\033[0m"
	gh release create --repo LeoNatan/EPSpy "$VERSION" --title "$VERSION" --notes ""
fi

if [ -z "$DRY_RUN" ]; then
	echo -e "\033[1;34mUploading ZIP attachment to release\033[0m"
	gh release upload --repo LeoNatan/EPSpy "$VERSION" "${ZIP_FILE}"
fi

if [ -z "$DRY_RUN" ]; then
	echo -e "\033[1;34mCleaning up\033[0m"
	rm -f "${RELEASE_NOTES_FILE}"
	rm -f "${ZIP_FILE}"
	rm -fr "${ARCHIVE}"
	rm -fr "${EXPORT_DIR}"
fi
