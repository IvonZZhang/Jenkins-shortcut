#! /bin/sh
set +o posix
##
## Setup
##
${MODULE_INIT_CMD}
## Start with a clean environment
module purge
module load $PWD/cbs/setup_HOST
module load dot
app switch qt qt/5.12.8_64bit
app switch gcc gcc/4.9.1_64bit
app list

export BUILD="$WORKSPACE/BUILD"
export ULOGRBUILD=$BUILD

mkdir -p $BUILD

printenv  > envVars.prop

echo Skipping removal of BUILDS, only remove tests.
[ -e $BUILD/Testing ] && rm -rf $BUILD/Testing || echo "No $BUILD/Testing directory to delete."

## [ -e $BUILD ] && rm -rf $BUILD || echo "No $BUILD directory to delete."

#
# CMake Build
#
cd "$BUILD"
cmake -G Ninja \
   -DCMAKE_BUILD_TYPE=Debug \
   -DCTEST_GENERATE_XUNIT_FILES=ON \
   -DCBS_BUILD_WARNING_LEVEL=LOW \
   "$ULOGRROOT/src"
   
ninja -j8
        
ninja install

$BUILD/delivery/bin/ulogr2text --help > ulogr2text_out.txt 2>&1

export  QT_QPA_PLATFORM=minimal
# ctest --timeout=300 --force-new-ctest-process -O ctest.out -T Test --output-on-failure -j1

# 
# Squish
#
app load squish/6.5.2_qt512_dbg_64bit
app load tigervnc/1.7.0

app load $ULOGRROOT/setup_squish

mkdir -p $ULOGRBUILD/squish_temp
export SQUISH_TEMP=$ULOGRBUILD/squish_temp

export SQUISH_FOR_JENKINS=$WORKSPACE/uLogR/src/tests/squish/jenkins 
# setenv SQUISH_LICENSEKEY_DIR=/var/lib/jenkins/etc # Don't store the license file in the SCM.
# setenv SQUISH_SCRIPT_DIR=$ULOGRROOT/src/tests/squish/common
# setenv SQUISH_USER_SETTINGS_DIR=$WORKSPACE/.squish
export ULOGR_ARTIFICIAL_SRCREF_FILES=$ULOGRROOT/src/tests/srcref_files

export SQUISHRUNNER_TAGS="--tags ~@target --tags ~@T_ULOGR-1346 --tags ~@workinprogress --tags ~@replay --tags ~@deprecated"
# export SQUISHXML2HTML_PY="/u-blox/gallery/froglogic/squish/lin_64/6.2_qt56/examples/regressiontesting/squishxml2html.py"
set -x

evaluate_squish_report_py=$WORKSPACE/uLogR/src/tests/squish/scripts/evaluate_squish_report.py
export EVITA_TARGET_PORT=8890

set +x
echo "ULOGRROOT=$ULOGRROOT"
echo "ULOGRBUILD=$ULOGRBUILD"
echo "SQUISH_FOR_JENKINS=$SQUISH_FOR_JENKINS"
echo "SQUISH_LICENSEKEY_DIR=$SQUISH_LICENSEKEY_DIR"
echo "SQUISH_SCRIPT_DIR=$SQUISH_SCRIPT_DIR"
echo "SQUISHRUNNER_TAGS=$SQUISHRUNNER_TAGS"
echo "EVITA_TARGET_PORT=$EVITA_TARGET_PORT"
echo "ULOGR_ARTIFICIAL_SRCREF_FILES=$ULOGR_ARTIFICIAL_SRCREF_FILES"
set -x

set +x
cd $WORKSPACE

#
# vncserver
#
chmod u+rwx $HOME
mkdir -p $HOME/.vnc
chmod u+w $HOME/.vnc/passwd ||:
cp -v $SQUISH_FOR_JENKINS/.vnc/passwd $HOME/.vnc/passwd # Password: jenkins
chmod go-r $HOME/.vnc/passwd # Own passwd file must be private.

# VNC configuration
cat > $HOME/.vnc/config <<EOF
geometry=1400x1050
EOF

echo "VNC Server configuration: OK"

(
   vncserver -name jenkins_1 -xstartup $SQUISH_FOR_JENKINS/squish-xstartup -geometry 1280x800
   #echo "New 'jenkins_1' desktop is be-lvn-pm-000.cog.cognovo.com:99"  # Simulation
   #sleep 999 # Simulation
) > vncserver.out 2>&1 &
pid_vncserver=$!
sleep 16 # VNC server usually takes 4 seconds. Double it for safety.
disp=$(awk 'BEGIN { FS="[ :]" } /^New/ { printf(":%s\n", $6) }' vncserver.out)
echo "Using X display: $disp"
if [ "$disp" == "" ]
then
    exit 1
fi

export DISPLAY="${disp}.0" # e.g. ":25.0"
echo "DISPLAY=$DISPLAY"
echo "SQUISH_USER_SETTINGS_DIR=$SQUISH_USER_SETTINGS_DIR"

echo "Setting up squishrunner..."
autName=ulogr
autDir=$ULOGRBUILD/delivery/bin
autAuthority=localhost:4324
squishrunner --port $port --config setGlobalScriptDirs $SQUISH_SCRIPT_DIR
squishrunner --port $port --config addAUT $autName $autDir
squishrunner --port $port --config addAttachableAUT $autName localhost:9999
set -x
cat $SQUISH_USER_SETTINGS_DIR/ver1/paths.ini
cat $SQUISH_USER_SETTINGS_DIR/ver1/server.ini
set +x

remove_ulogr_config() {
  (
    cd $HOME/.ubx/ulogr
    rm -vf *.json *.ini
  )
}

for suite_dir in $(ls -d $ULOGRROOT/src/core/tests/suite_* $ULOGRROOT/src/plugins/*/tests/suite_* $ULOGRROOT/src/api/tests/suite_*)      	   
do
   if [[ $suite_dir == */suite_BDD_FlashFSViewer ]]
   then
      continue
   fi
   if contains "$suite_dir" suite_BDD_Api
   then
      timeout="--timeout 3000"
   else
      timeout=""
   fi   

   set -x
   remove_ulogr_config
   squishrunner --testsuite $suite_dir --local $timeout \
      $SQUISHRUNNER_TAGS \
      --reportgen xml2.2,$WORKSPACE/squishrunner_report.xml \
      --reportgen html,$WORKSPACE/squishrunner_report_html/ \
      --reportgen stdout \
      >> $ULOGRBUILD/squishrunner.out 2>&1
   set +x
done
