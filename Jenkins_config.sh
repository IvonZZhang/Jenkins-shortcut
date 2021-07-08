# ****** Usage ******
#
# --build-type         <debug|release>  Affect build by setting CMAKE_BUILD_TYPE.
# --<testsuite>                         Only specified Squish test suites will run.
# -I, --test-information <Start,End,Stride,test#,test#|Test file>
#                                       Same option in ctest to run a specific number of tests by number.
# --run-coverage                        Build with coverage enabled and generate coverage report. Omitted with --build-type release option present
# --mno                                 Build the MNO variant
#
# ** E.g. To run all ctests and all Squish test suites on a debug build with coverage report generated**
# $WORKSPACE/uLogR/src/tests/squish/jenkins/lin/Jenkins_config.sh --run-coverage \
#   --build-type debug \
#   --api \
#   --atconsole \
#   --core \
#   --dashboard \
#   --evi \
#   --flashfilesystemviewer \
#   --genericmessageview \
#   --graphviewer \
#   --listview \
#   --memoryviewer \
#   --objectviewer \
#   --psmessageviewer \
#   --runtimefilter \
#   --settingsmanager \
#   --testmanager
#
# ** E.g. To run only the first 50 ctests and Squish test suite_BDD_Core on a release build without coverage report**
# $WORKSPACE/uLogR/src/tests/squish/jenkins/lin/Jenkins_config.sh --run-coverage \
#   --build-type release \
#   -I 1,50
#   --core

#! /bin/sh
# ulimit -f 10000000 # 10 GB
set +o posix
# Jenkins execute shell scripts with `/bin/sh -xe`, which means it exits immediately after a failure
# We want it to execute anyway, even if e.g. some ctests fails. So disable option -e manually
set +e

set +x
echo "*********************************************"
echo "************   PART ZERO   ******************"
echo "************  ARG PARSING  ******************"
echo "*********************************************"

JENKINS_BUILD_TYPE=
CTEST_RANGE=
RUN_COVERAGE=
MNO_BUILD=
UNKNOWN_OPTIONS=()
SUITES_TO_RUN=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -t|--build-type)
      JENKINS_BUILD_TYPE="$2"
      shift # past argument
      shift # past value
      ;;
    --api)
      SUITES_TO_RUN+=("suite_BDD_Api")
      shift # past argument
      ;;
    --atconsole)
      SUITES_TO_RUN+=("suite_BDD_ATConsole")
      shift # past argument
      ;;
    --bandwidth)
      # SUITES_TO_RUN+=("suite_BDD_Bandwidth")
      echo "Suite_BDD_Bandwidth has deprecated and is ignored."
      shift # past argument
      ;;
    --core)
      SUITES_TO_RUN+=("suite_BDD_Core")
      shift # past argument
      ;;
    --dashboard)
      SUITES_TO_RUN+=("suite_BDD_Dashboard")
      shift # past argument
      ;;
    --evi)
      SUITES_TO_RUN+=("suite_BDD_Evi")
      shift # past argument
      ;;
    --flashfilesystemviewer)
      SUITES_TO_RUN+=("suite_BDD_FlashFileSystemViewer")
      shift # past argument
      ;;
    --genericmessageview)
      SUITES_TO_RUN+=("suite_BDD_GenericMessageView")
      shift # past argument
      ;;
    --graphviewer)
      SUITES_TO_RUN+=("suite_BDD_GraphViewer")
      shift # past argument
      ;;
    --listview)
      SUITES_TO_RUN+=("suite_BDD_ListView")
      shift # past argument
      ;;
    --memoryviewer)
      SUITES_TO_RUN+=("suite_BDD_MemoryViewer")
      shift # past argument
      ;;
    --messageconsole)
      # SUITES_TO_RUN+=("suite_BDD_MessageConsole")
      echo "Suite_BDD_MessageConsole has deprecated and is ignored."
      shift # past argument
      ;;
    --objectviewer)
      SUITES_TO_RUN+=("suite_BDD_ObjectViewer")
      shift # past argument
      ;;
    --psmessageviewer)
      SUITES_TO_RUN+=("suite_BDD_PSMessageViewer")
      shift # past argument
      ;;
    --runtimefilter)
      SUITES_TO_RUN+=("suite_BDD_RuntimeFilter")
      shift # past argument
      ;;
    --settingsmanager)
      SUITES_TO_RUN+=("suite_BDD_SettingsManager")
      shift # past argument
      ;;
    --testmanager)
      SUITES_TO_RUN+=("suite_BDD_TestManager")
      shift # past argument
      ;;
    -I|--test-information)
      CTEST_RANGE="$2"
      shift # past argument
      shift # past value
      ;;
    --run-coverage)
      RUN_COVERAGE=YES
      shift # past argument
      ;;
    --mno)
      MNO_BUILD=YES
      shift # past argument
      ;;
    *)    # unknown option
      UNKNOWN_OPTIONS+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

set -- "${UNKNOWN_OPTIONS[@]}" # restore unknown options
echo "Unknown options: ${UNKNOWN_OPTIONS[*]}"

if [[ ! $JENKINS_BUILD_TYPE == "release" ]] && [[ ! $JENKINS_BUILD_TYPE == "debug" ]]; then
    echo "Please specify build type using '-t or --build-type <release|debug>'"
    exit 1
fi

echo "================================================================================================="
echo "Running configurations for Squish test for uLogR 64bit $JENKINS_BUILD_TYPE build."
echo "Suites to run: ${SUITES_TO_RUN[*]}"
echo "================================================================================================"

echo "*********************************************"
echo "************   PART ONE    ******************"
echo "************  ENVIRONMENT  ******************"
echo "*********************************************"
set -x

${MODULE_INIT_CMD}
## Start with a clean environment
module purge
set +x
module load $PWD/cbs/setup_HOST
module load dot
app list
set -x

export BUILD="$WORKSPACE/BUILD"
export ULOGRBUILD=$BUILD
# Print directories in PATH line by line
sed 's/:/\n/g' <<< "$PATH"
mkdir -p $BUILD

printenv  > envVars.prop

set +x
echo "*********************************************"
echo "***********    PART TWO    ******************"
echo "*********** BUILD & DEPLOY ******************"
echo "*********************************************"
set -x

echo Skipping removal of BUILDS, only remove tests.
[ -e $BUILD/Testing ] && rm -rf $BUILD/Testing || echo "No $BUILD/Testing directory to delete."

## [ -e $BUILD ] && rm -rf $BUILD || echo "No $BUILD directory to delete."

cd "$BUILD"

set +x
echo "=============================================="
echo "Current working directory is $PWD"
echo "=============================================="

echo "********************************"
echo "*******     CMAKE     **********"
echo "********************************"
set -x

if [[ $MNO_BUILD == "YES" ]]; then
    MNO_OPTION='-DULOGR_VARIANT=MNO'
fi

if [[ $RUN_COVERAGE == "YES" ]] && [[ $JENKINS_BUILD_TYPE == "debug" ]]; then
    cmake-gcc -G Ninja \
       -DCMAKE_BUILD_TYPE=Debug \
       -DCBS_BUILD_OPTIONS_COVERAGE=ON \
       -DCTEST_GENERATE_XUNIT_FILES=ON \
       -DCBS_BUILD_WARNING_LEVEL=LOW \
       "$ULOGRROOT/src"
else
    cmake-gcc -G Ninja \
       -DCMAKE_BUILD_TYPE=RelWithDebInfo \
       -DCTEST_GENERATE_XUNIT_FILES=ON \
       -DCBS_BUILD_WARNING_LEVEL=LOW \
       "$ULOGRROOT/src"
fi

set +x
echo "********************************"
echo "*******     NINJA     **********"
echo "********************************"
set -x

ninja -j6
if [ $? -ge 1 ]; then
    echo "WARNING: Building ui_zipselection.h"
    ninja ui_zipselection.h
    ninja -j6
fi
[ $? -ge 1 ] && ninja -j1

if [ $? -ge 1 ]; then
    ninja -j1
    if [ $? -ge 1 ]; then
        echo "ERROR: Something is very wrong and the code doesn't even compile!"
        exit 1
    fi
fi

set +x
echo "********************************"
echo "*******     DEPLOY    **********"
echo "********************************"
set -x

ninja install

# $BUILD/delivery/bin/ulogr2text --help > ulogr2text_out.txt 2>&1

# export  QT_QPA_PLATFORM=minimal

if [[ $RUN_COVERAGE == "YES" ]] && [[ $JENKINS_BUILD_TYPE == "debug" ]]; then
    app load lcov
    lcov --zerocounters --directory  $ULOGRBUILD
    echo "Coverage counters reset to zero"
fi

set +x
echo "*********************************************"
echo "************    PART THREE     **************"
echo "************      CTEST        **************"
echo "*********************************************"
set -x

ctest --timeout=300 --force-new-ctest-process -O ctest.out -T Test --output-on-failure -j1 -I $CTEST_RANGE

set +x
echo "*********************************************"
echo "************     PART FOUR     **************"
echo "************      SQUISH       **************"
echo "*********************************************"

echo "=============================================="
echo "Clean up old report, settings file, crash dumps, temporary files..."
echo "=============================================="
set -x
# Clean up old report
SQUISH_REPORT_DIR=$WORKSPACE/Report_Squish
if [ ! -d "${SQUISH_REPORT_DIR}" ]; then
    echo ">>> Creating Squish report directory"
    mkdir -p $SQUISH_REPORT_DIR
else
    echo ">>> Removing any previous Squish reports from ${SQUISH_REPORT_DIR}"
    rm -rf ${SQUISH_REPORT_DIR}/*
fi

rm -rvf $WORKSPACE/build.status

# To store SquishDumps in workspace instead of a user's space
export SQUISH_DUMP_FILE_PATH=$WORKSPACE/SquishDumps

# Clean up old Squish crash dumps
rm -rvf $SQUISH_DUMP_FILE_PATH

# Clean up settings file
# uLogR settings directory should be empty to ensure tests run properly
remove_ulogr_config() {
  (
    rm -vf $HOME/.ubx/ulogr*.json 
    rm -vf $HOME/.ubx/ulogr*.ini
  )
}
remove_ulogr_config

set +x
cd $WORKSPACE
echo Current working directory is $PWD
echo "=============================================="
echo "Set up VNC"
echo "=============================================="

app load tigervnc/1.7.0
set -x

# Set VNC config and password
chmod u+rwx $HOME
mkdir -p $HOME/.vnc
chmod u+w $HOME/.vnc/passwd ||:
export SQUISH_FOR_JENKINS=$WORKSPACE/uLogR/src/tests/squish/jenkins 
cp -v $SQUISH_FOR_JENKINS/.vnc/passwd $HOME/.vnc/passwd # Password: jenkins
chmod go-r $HOME/.vnc/passwd # Own passwd file must be private.

echo "Launching VNC Server..."

(
   vncserver -name jenkins_1 -xstartup $SQUISH_FOR_JENKINS/squish-xstartup -geometry 1920x1080
) > $WORKSPACE/vncserver.out 2>&1 &
pid_vncserver=$!
sleep 8 # VNC server usually takes 4 seconds. Double it for safety.
disp=$(awk 'BEGIN { FS="[ :]" } /^New/ { printf(":%s\n", $6) }' $WORKSPACE/vncserver.out)
echo "Using X display: $disp"
if [ "$disp" == "" ]
then
    exit 1
fi

export DISPLAY="${disp}.0" # e.g. ":16.0"
echo "DISPLAY=$DISPLAY"

set +x
echo "=============================================="
echo "Set up Squish"
echo "=============================================="

app load 64bit $ULOGRROOT/setup_squish
set -x

# Prevent mainwindow from losing focus.
# Ref. https://kb.froglogic.com/squish/qt/howto/bringing-window-foreground/ and https://superuser.com/questions/143044/how-to-prevent-new-windows-from-stealing-focus-in-gnome
gconftool-2 -s -t string /apps/metacity/general/focus_new_windows "None"

# SQUISH_TEMP is referred in Squish test scripts storing generated files during testing etc.
mkdir -p $ULOGRBUILD/squish_temp
export SQUISH_TEMP=$ULOGRBUILD/squish_temp

export SQUISH_LICENSEKEY_DIR=/var/lib/jenkins/etc # Don't store the license file in the SCM.
export SQUISH_USER_SETTINGS_DIR=$WORKSPACE/.squish
export ULOGR_ARTIFICIAL_SRCREF_FILES=$ULOGRROOT/src/tests/srcref_files
export EVITA_TARGET_PORT=8890

# Register AUT to squishserver
echo "Registering ulogr to Squish..."
# autAuthority=localhost:4324
# This adds this path to its settings file paths.ini
export SQUISH_SCRIPT_DIR=$ULOGRROOT/src/tests/squish/common
squishrunner --config setGlobalScriptDirs $SQUISH_SCRIPT_DIR

# These add AUT configs to server.ini
squishserver --config addAUT ulogr $ULOGRBUILD/delivery/bin
squishserver --config addAUT ulogr.exe $ULOGRBUILD/delivery/lib64
squishserver --config addAttachableAUT ulogr localhost:9999

set -x
echo "==========================================="
echo "Squish server settings:"
cat $SQUISH_USER_SETTINGS_DIR/ver1/paths.ini
cat $SQUISH_USER_SETTINGS_DIR/ver1/server.ini
echo "==========================================="
set +x

export SQUISHRUNNER_TAGS="--tags ~@target --tags ~@T_ULOGR-1346 --tags ~@workinprogress --tags ~@replay --tags ~@deprecated --tags ~@serial --tags ~@listenOnly"
# export SQUISHXML2HTML_PY="/u-blox/gallery/froglogic/squish/lin_64/6.2_qt56/examples/regressiontesting/squishxml2html.py"
SUITES_TO_RUN_IN_MNO_BUILD=(suite_BDD_Api suite_BDD_Core suite_BDD_Dashboard suite_BDD_GenericMessageView suite_BDD_GraphViewer suite_BDD_ListView suite_BDD_ObjectViewer suite_BDD_PSMessageViewer)

# evaluate_squish_report_py=$WORKSPACE/uLogR/src/tests/squish/scripts/evaluate_squish_report.py

set +x
echo "=========================================="
echo "Some crucial environment variables:"
echo "ULOGRROOT=$ULOGRROOT"
echo "ULOGRBUILD=$ULOGRBUILD"
echo "SQUISH_FOR_JENKINS=$SQUISH_FOR_JENKINS"
echo "SQUISH_LICENSEKEY_DIR=$SQUISH_LICENSEKEY_DIR"
echo "SQUISH_SCRIPT_DIR=$SQUISH_SCRIPT_DIR"
echo "SQUISHRUNNER_TAGS=$SQUISHRUNNER_TAGS"
echo "EVITA_TARGET_PORT=$EVITA_TARGET_PORT"
echo "ULOGR_ARTIFICIAL_SRCREF_FILES=$ULOGR_ARTIFICIAL_SRCREF_FILES"
echo "SQUISH_USER_SETTINGS_DIR=$SQUISH_USER_SETTINGS_DIR"
echo "=========================================="
set -x

echo "============== App List =================="
app list

cd $WORKSPACE

for suite_dir in $(ls -d $ULOGRROOT/src/core/tests/suite_* $ULOGRROOT/src/plugins/*/tests/suite_* $ULOGRROOT/src/api/tests/suite_*)
do
    set -x

    suite_name=$(echo $suite_dir | sed -E "s/^.*\/(\w+)/\1/")

    if [[ ! " ${SUITES_TO_RUN[@]} " =~ " ${suite_name} " ]]; then
        # Not asked to run this suite, skip
        continue
    fi

    if [[ $MNO_BUILD == "YES" ]] && [[ ! " ${SUITES_TO_RUN_IN_MNO_BUILD[@]} " =~ " ${suite_name} " ]]; then
        # This is a MNO build and current plugin is not included. Skipping
        continue
    fi

    remove_ulogr_config

    set +x
    echo
    echo "------------------ START: $suite_name --------------------------"
    echo
    set -x
    squishrunner --testsuite $suite_dir --local --retry 2 $timeout $SQUISHRUNNER_TAGS \
                 --reportgen xml2.2,$SQUISH_REPORT_DIR/squish_report_xml/squish_report_${suite_name}.xml \
                 --reportgen html,$SQUISH_REPORT_DIR/squish_report_html/ \
                 --reportgen stdout > >(tee -a $SQUISH_REPORT_DIR/squish.out) 2> >(tee -a $SQUISH_REPORT_DIR/squish.out >&2)
    set +x
    echo
    echo "------------------ FINISHED: $suite_name ------------------------"
    echo
    set -x
done

echo "=============================================="
echo "Clean up Squish and VNC"
echo "=============================================="

echo -n "Shutting down Xvnc at $disp..."
vncserver -kill $disp

if [[ ! $RUN_COVERAGE == "YES" ]] || [[ ! $JENKINS_BUILD_TYPE == "debug" ]]; then
    echo "Not a debug build or not asked to run coverage. Finished and exiting..."
    exit 0
fi

set +x
echo "*********************************************"
echo "************     PART FIVE     **************"
echo "************     COVERAGE      **************"
echo "*********************************************"
set -x

COVERAGE_REPORT_DIR=$WORKSPACE/Report_Coverage
if [ ! -d "$COVERAGE_REPORT_DIR" ]; then
    echo ">>> Creating coverage report directory"
    install -d -o jenkins -g jenkins -m 0755 "${COVERAGE_REPORT_DIR}"
else
    echo ">>> Removing any previous lcov reports from ${COVERAGE_REPORT_DIR}"
    rm -rf ${COVERAGE_REPORT_DIR}/*
fi

# The data is now in $ULOGRBUILD as it would be after a normal build/test run
# Extracting the data for the cobertura publisher
app switch python python/2.7.2.5_64bit
VIRTUALENV_ENV_PATH=$ULOGRBUILD/gcovr_env
virtualenv --system-site-packages $VIRTUALENV_ENV_PATH
source $VIRTUALENV_ENV_PATH/bin/activate
pip install --disable-pip-version-check gcovr # Obtain latest gcovr
echo "gcovr executable is:"
which gcovr
gcovr -r $ULOGRBUILD --xml --output=${COVERAGE_REPORT_DIR}/coberturareport.xml

# Use lcov to extract the coverage data to html data
LCOV_ARCHIVE="${COVERAGE_REPORT_DIR}/lcov-archive"
echo ">>> Creating lcov archive directory"
install -d -o jenkins -g jenkins -m 0755 "${LCOV_ARCHIVE}"

# Possibly the info file can also be filtered to avoid unwanted directories/libraries to be counted
lcov -d  $ULOGRBUILD --capture --output-file  ${LCOV_ARCHIVE}/lcov_origin.info

# Filter out the stuff we don't want
# Important: Don't use '/u-blox/*' as a removal pattern, because it could remove entries that are in 
# the Jenkins workspace on some build nodes (e.g. '/u-blox/work/jenkins000/...').
#lcov --remove ${LCOV_ARCHIVE}/lcov.info -o ${LCOV_ARCHIVE}/lcov.info \
#        '/u-blox/gallery/*' \
#        '*pools.cpp' \
#        '*rapidjson*' \
#        "BUILD/*" \
#        "uLogR/src/tests/*" \
#        "datamodel/tests/*" \
#        "uLogR/src/plugins/runtime_filter/tests/*" \
#        "evita/*" \
#        '*/moc_*.cpp' \
#        '*autogen*'
#lcov --remove ${LCOV_ARCHIVE}/lcov.info "/work/jenkins/*"  -o ${LCOV_ARCHIVE}/lcov.info

# Extract the stuff we want (only files under $ULOGRROOT/src)
lcov -e ${LCOV_ARCHIVE}/lcov_origin.info "$ULOGRROOT/src/*" -o ${LCOV_ARCHIVE}/lcov_extract.info
lcov -e ${LCOV_ARCHIVE}/lcov_origin.info "$ULOGRROOT/src/*" --ignore-errors gcov,source,graph -o ${LCOV_ARCHIVE}/lcov_extract_noerror.info

# Generate the html files from the info
genhtml ${LCOV_ARCHIVE}/lcov_origin.info --prefix ${ULOGRROOT} --ignore-errors source -o ${LCOV_ARCHIVE}/html
genhtml ${LCOV_ARCHIVE}/lcov_extract.info --prefix ${ULOGRROOT} --ignore-errors source -o ${LCOV_ARCHIVE}/html
genhtml ${LCOV_ARCHIVE}/lcov_extract.info --prefix ${ULOGRROOT} --ignore-errors gcov,source,graph -o ${LCOV_ARCHIVE}/html

