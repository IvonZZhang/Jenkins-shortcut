#! /bin/sh
# ulimit -f 10000000 # 10 GB
set +o posix

set +x
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

cmake-gcc -G Ninja \
   -DCMAKE_BUILD_TYPE=Debug \
   -DCBS_BUILD_OPTIONS_COVERAGE=ON \
   -DCTEST_GENERATE_XUNIT_FILES=ON \
   -DCBS_BUILD_WARNING_LEVEL=LOW \
   "$ULOGRROOT/src"

set +x
echo "********************************"
echo "*******     NINJA     **********"
echo "********************************"
set -x

ninja -j6

set +x
echo "********************************"
echo "*******     DEPLOY    **********"
echo "********************************"
set -x

ninja install

# $BUILD/delivery/bin/ulogr2text --help > ulogr2text_out.txt 2>&1

# export  QT_QPA_PLATFORM=minimal
# ctest --timeout=300 --force-new-ctest-process -O ctest.out -T Test --output-on-failure -j1

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
rm -rvf $WORKSPACE/squish_report_xml/
rm -rvf $WORKSPACE/squish_report_html/
rm -rvf $WORKSPACE/squish_stdout/
mkdir $WORKSPACE/squish_report_xml
mkdir $WORKSPACE/squish_report_html
mkdir $WORKSPACE/squish_stdout
rm -rvf $WORKSPACE/squishserver.out
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
   vncserver -name jenkins_1 -xstartup $SQUISH_FOR_JENKINS/squish-xstartup -geometry 1400x1050
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

app load squish/6.7.0_qt512_64bit
app load 64bit $ULOGRROOT/setup_squish
set -x

# Prevent mainwindow from losing focus. Ref. https://kb.froglogic.com/squish/qt/howto/bringing-window-foreground/ and https://superuser.com/questions/143044/how-to-prevent-new-windows-from-stealing-focus-in-gnome
gconftool-2 -s -t string /apps/metacity/general/focus_new_windows "None"

# Where is this used?
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
# squishrunner --config addAttachableAUT ulogr localhost:9999

set -x
echo "==========================================="
echo "Squish server settings:"
cat $SQUISH_USER_SETTINGS_DIR/ver1/paths.ini
cat $SQUISH_USER_SETTINGS_DIR/ver1/server.ini
echo "==========================================="
set +x

export SQUISHRUNNER_TAGS="--tags ~@target --tags ~@T_ULOGR-1346 --tags ~@workinprogress --tags ~@replay --tags ~@deprecated --tags ~@serial --tags ~@listenOnly"
# export SQUISHXML2HTML_PY="/u-blox/gallery/froglogic/squish/lin_64/6.2_qt56/examples/regressiontesting/squishxml2html.py"
set -x

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

# squishrunner --testsuite $WORKSPACE/uLogR/src/plugins/memory_viewer/tests/suite_BDD_MemoryViewer --local --tags '~@target' --tags '~@T_ULOGR-1346' --tags '~@workinprogress' --tags '~@replay' --tags '~@deprecated' --reportgen xml2.2,$WORKSPACE/squish_report_xml/squish_report.xml --reportgen html,$WORKSPACE/squish_report_html/ --reportgen stdout | tee -a $ULOGRBUILD/squish.out 2>&1
for suite_dir in $(ls -d $ULOGRROOT/src/core/tests/suite_* $ULOGRROOT/src/plugins/*/tests/suite_* $ULOGRROOT/src/api/tests/suite_*)
do
    # Deprecated test suites
    if [[ $suite_dir == */suite_BDD_FlashFSViewer ]] || [[ $suite_dir == */suite_BDD_BandWidth ]] || [[ $suite_dir == */suite_BDD_MessageConsole ]]
    then
        continue
    fi

    set -x
    remove_ulogr_config
    
    suite_name=$(echo $suite_dir | sed -E "s/^.*\/(\w+)/\1/")
    set +x
    echo
    echo "------------------ START: $suite_name --------------------------"
    echo
    set -x
    squishrunner --testsuite $suite_dir --local --retry 2 $timeout $SQUISHRUNNER_TAGS --reportgen xml2.2,$WORKSPACE/squish_report_xml/squish_report_${suite_name}.xml --reportgen html,$WORKSPACE/squish_report_html/ --reportgen stdout > >(tee -a $ULOGRBUILD/squish.out) 2> >(tee -a $ULOGRBUILD/squish.out >&2)
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

set +x
echo "*********************************************"
echo "************     PART FIVE     **************"
echo "************     COVERAGE      **************"
echo "*********************************************"
set -x

app load gcovr
app load lcov

