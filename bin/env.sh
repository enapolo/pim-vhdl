#
# @brief	Add the directory containing this file to the PATH
#
# @usage	source this file from anywhere
#

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export PATH=$CURRENT_DIR:$PATH

if ! ghdl -v >/dev/null 2>&1
then
	>&2 echo '***************************************************************************'
	>&2 echo '*** WARNING: ghdl not found, trying to install it in '$CURRENT_DIR/.cache
	>&2 echo '***************************************************************************'

	HOME=$CURRENT_DIR/.cache $CURRENT_DIR/../travis/deps.sh
	export PATH=$CURRENT_DIR/.cache/ghdl/bin:$PATH

	if uname | grep Linux > /dev/null
	then
		export LD_LIBRARY_PATH=$HOME/lib:$LD_LIBRARY_PATH
	fi
fi
