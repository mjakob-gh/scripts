#!/bin/sh
# shellcheck disable=SC2039,SC2059,SC2181

# Load filemon module needed for META_MODE
kldload filemon

# Check if META_MODE is enabled
printf "META_MODE: "
grep "^WITH_META_MODE=YES" /etc/src-env.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "enabled"
else
    echo "disabled"
fi

# parallel builds
NUM_CPU=$( sysctl -n hw.ncpu )
SRC_DIR="/usr/src"

# ANSI Color Codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"

# Bold an underline
BOLD="\033[1m"
UNDERLINE="\033[4m"

# End ofANSI Code
ANSI_END="\033[0m"

LOG_FILE="/tmp/buildsystem_$(date "+%Y%m%d%H%M").log"

checkResult ()
{
    if [ "$1" -eq 0 ]; then
        printf "${GREEN}[OK]${ANSI_END}\n"
    else
        printf "${RED}[ERROR]${ANSI_END}\n"
        echo "Check Buildlog ${LOG_FILE}"
        echo ""
        exit 1
    fi
}

get_revision()
{
    ## SubVersion
    #LAST_CHANGED_REVISION=$(svnlite info --no-newline --show-item last-changed-revision ${SRC_DIR})

    ## Git
    LAST_CHANGED_REVISION=$( git -C "${SRC_DIR}" rev-parse --short HEAD )
}

get_timestamp()
{
    ## SubVersion
    #LAST_CHANGED_DATE=$(svnlite info --no-newline --show-item last-changed-date ${SRC_DIR} | sed 's/\.[0-9]*Z$//')
    #SOURCE_DATE_EPOCH=$(date -juf "%FT%T" ${LAST_CHANGED_DATE} "+%s")

    ## Git
    LAST_CHANGED_DATE=$( git --no-pager -C "${SRC_DIR}" log -1 --date=short --pretty=format:%cI )
    SOURCE_DATE_EPOCH=$( git --no-pager -C "${SRC_DIR}" log -1 --date=short --pretty=format:%ct )

    export SOURCE_DATE_EPOCH
}

start()
{
    clear
    echo "Start building system"
    echo "---------------------"
    echo "* cd ${SRC_DIR}"

    cd "${SRC_DIR}" || exit 1
    TIME_START=$(date +%s)
}

make_update()
{
    printf "* make update.........."
    #make update > ${LOG_FILE}
    git -C "${SRC_DIR}" pull --ff-only > "${LOG_FILE}" 2>&1
    checkResult $?

}

info()
{
    echo "---------------------------------------"
    echo "Logfile:               ${LOG_FILE}"
    echo "last-changed-revision: ${LAST_CHANGED_REVISION}"
    echo "last-changed-date:     ${LAST_CHANGED_DATE}"
    echo "SOURCE_DATE_EPOCH:     ${SOURCE_DATE_EPOCH}"
    echo "---------------------------------------"
}

make_buildworld()
{
    printf "* make buildworld......"
    make -j${NUM_CPU} buildworld >> "${LOG_FILE}" 2>&1
    checkResult $?
}

make_installworld()
{
    printf "* make installworld...."
    make installworld >> "${LOG_FILE}" 2>&1
    checkResult $?
}

make_buildkernel()
{
    printf "* make buildkernel....."
    make -j${NUM_CPU} buildkernel >> "${LOG_FILE}" 2>&1
    checkResult $?
}

make_installkernel()
{
    printf "* make installkernel..."
    make installkernel >> "${LOG_FILE}" 2>&1
    checkResult $?
}

make_packages()
{
    printf "* make packages........"
    make -j${NUM_CPU} packages >> "${LOG_FILE}" 2>&1
    checkResult $?
}

make_delete_old()
{
    printf "* make delete-old......"
    make -DBATCH_DELETE_OLD_FILES delete-old >> "${LOG_FILE}" 2>&1
    checkResult $?
}

make_delete_old_libs()
{
    printf "* make delete-old-libs."
    make -DBATCH_DELETE_OLD_FILES delete-old-libs >> "${LOG_FILE}" 2>&1
    checkResult $?
}

compress_logs()
{
    printf "* compressing logfile.."
    xz "${LOG_FILE}"
    checkResult $?
}

end()
{
    TIME_END=$( date +%s )
    TIME_DIFF=$((TIME_END - TIME_START))
    echo "---------------------------------------"
    echo "Duration: $((TIME_DIFF / 3600))h $(((TIME_DIFF / 60) % 60))m $((TIME_DIFF % 60))s"

    echo ""
    echo "* please run \"mergemaster -iFU\" and read ${SRC_DIR}/UPDATING"
}

## start the update process
start

make_update

get_revision
get_timestamp

info

make_buildworld
make_installworld

make_buildkernel
make_installkernel

make_packages

make_delete_old
make_delete_old_libs

compress_logs

end