if [[ $# -ne 1 ]]
then
	echo "Usage: $0 <tag message>"
	exit 1
fi

tag_message="$1"

SCRIPT_DIR=$(dirname $0)
cd $SCRIPT_DIR


CURRENT_VERSION=$(git describe --tags --abbrev=0 --match 'v*' 2> /dev/null || true)
if [[ -z $CURRENT_VERSION ]]
then
	NEW_VERSION='v0.1.0'
else
	NEW_VERSION=$(echo $CURRENT_VERSION | awk -F. '{OFS="."; $NF+=1; print $0}')
fi

git tag -d stable || true
git push origin :stable || true
git tag -a stable -m "Last Stable Release"
git push origin stable
git tag -a "$NEW_VERSION" -m "$tag_message"
git push origin "$NEW_VERSION"
