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
   -DCBS_BUILD_WARNING_LEVEL=HIGH \
   "$ULOGRROOT/src"
   
ninja
        
ninja install

$BUILD/delivery/bin/ulogr2text --help > ulogr2text_out.txt 2>&1

export  QT_QPA_PLATFORM=minimal
ctest --timeout=300 --force-new-ctest-process -O ctest.out -T Test --output-on-failure -j1
