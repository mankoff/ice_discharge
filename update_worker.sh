#!/usr/bin/env bash
# [[file:ice_discharge.org::*Local][Local:2]]
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
MSG_OK() { printf "${GREEN}${1}${NC}\n"; }
MSG_WARN() { printf "${ORANGE}WARNING: ${1}${NC}\n"; }
MSG_ERR() { echo "${RED}ERROR: ${1}${NC}\n" >&2; }
export GRASS_VERBOSE=3
# export GRASS_MESSAGE_FORMAT=silent

if [ -z ${DATADIR+x} ]; then
    echo "DATADIR environment varible is unset."
    echo "Fix with: \"export DATADIR=/path/to/data\""
    exit 255
fi

set -x # print commands to STDOUT before running them

trap ctrl_c INT
function ctrl_c() {
  MSG_WARN "Caught CTRL-C"
  MSG_WARN "Killing process"
  kill -term $$ # send this program a terminate signal
}
MSG_OK "Sentinel 1"
g.mapset -c Sentinel1
ROOT=${DATADIR}/Sentinel1/Sentinel1_IV_maps

find ${ROOT} -name "*.nc"
# FILE=$(find ${ROOT} -name "*.nc"|head -n1) # testing

FILE=$(find ${ROOT} -name "*.nc" | head -n1) # DEBUG
for FILE in $(find ${ROOT} -name "*.nc" | LC_ALL=C sort); do
  T=$(ncdump -v time $FILE | tail -n2 | tr -dc '[0-9]')
  DATE=$(date --utc --date="1990-01-01 +${T} days" --iso-8601)
  DATE_STR=$(echo ${DATE} | sed s/-/_/g)
  echo $DATE

  # TT=$(ncdump -v time_bnds $FILE | tail -n2 | head -n1)
  # T0=$(echo ${TT} | cut -d, -f1)
  # T1=$(echo ${TT} | cut -d, -f2 | tr -dc [0-9])
  # D0=$(date --date="1990-01-01 +${T0} days" --iso-8601)
  # D1=$(date --date="1990-01-01 +${T1} days" --iso-8601)

  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity" output=vx_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity" output=vy_${DATE_STR}

  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity_std" output=ex_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity_std" output=ey_${DATE_STR}
done
	
MAPSET=gates_100_5000
g.mapset Sentinel1
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
VX=$(g.list type=raster pattern=vx_????_??_?? | head -n1) # DEBUG
for VX in $(g.list type=raster pattern=vx_????_??_??); do
  VY=${VX/vx/vy}
  EX=${VX/vx/ex}
  EY=${VX/vx/ey}
  DATE=$(echo $VX | cut -d"_" -f2-)
  echo $DATE
  r.mapcalc "vel_eff_${DATE} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(${VX}), 0, abs(${VX}))) + if(gates_y@${MAPSET}, if(isnull(${VY}), 0, abs(${VY}))))"
  r.mapcalc "err_eff_${DATE} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(${EX}), 0, abs(${EX}))) + if(gates_y@${MAPSET}, if(isnull(${EY}), 0, abs(${EY}))))"
done
# Local:2 ends here
