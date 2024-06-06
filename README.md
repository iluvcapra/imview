# imview

ADM WAVE File Viewer/Inspector

## Work-in-Progress

This project is a work-in-progress and is not at this time useable.

## Example

```sh 
$ imview
AudioProgramme (APR_1001) "Atmos_Master"
 + AudioContent (ACO_1001) "DIAL"
   + AudioObject (AO_1001) "Bed 1-10" (AudioTrackUID count 10)
     + AudioPackFormat (AP_00011001) "AtmosCustomPackFormat1" (type: "DirectSpeakers")
       + AudioChannelFormat (AC_00011001) "RoomCentricLeft"
         -> AudioStreamFormat (AS_00011001)
       + AudioChannelFormat (AC_00011002) "RoomCentricRight"
         -> AudioStreamFormat (AS_00011002)
       + AudioChannelFormat (AC_00011003) "RoomCentricCenter"
         -> AudioStreamFormat (AS_00011003)
       + AudioChannelFormat (AC_00011004) "RoomCentricLFE"
         -> AudioStreamFormat (AS_00011004)
       + AudioChannelFormat (AC_00011005) "RoomCentricLeftSideSurround"
         -> AudioStreamFormat (AS_00011005)
       + AudioChannelFormat (AC_00011006) "RoomCentricRightSideSurround"
         -> AudioStreamFormat (AS_00011006)
       + AudioChannelFormat (AC_00011007) "RoomCentricLeftRearSurround"
         -> AudioStreamFormat (AS_00011007)
       + AudioChannelFormat (AC_00011008) "RoomCentricRightRearSurround"
         -> AudioStreamFormat (AS_00011008)
       + AudioChannelFormat (AC_00011009) "RoomCentricLeftTopSurround"
         -> AudioStreamFormat (AS_00011009)
       + AudioChannelFormat (AC_0001100a) "RoomCentricRightTopSurround"
         -> AudioStreamFormat (AS_0001100a)
   + AudioObject (AO_100b) "Object 11" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031001) "Atmos_Obj_1" (type: "Objects")
       + AudioChannelFormat (AC_00031001) "Atmos_Obj_1"
         -> AudioStreamFormat (AS_00031001)
 + AudioContent (ACO_1002) "MX"
   + AudioObject (AO_100c) "Object 12" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031002) "Atmos_Obj_2" (type: "Objects")
       + AudioChannelFormat (AC_00031002) "Atmos_Obj_2"
         -> AudioStreamFormat (AS_00031002)
 + AudioContent (ACO_1003) "FX"
   + AudioObject (AO_100d) "Object 13" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031003) "Atmos_Obj_3" (type: "Objects")
       + AudioChannelFormat (AC_00031003) "Atmos_Obj_3"
         -> AudioStreamFormat (AS_00031003)
   + AudioObject (AO_100e) "Object 14" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031004) "Atmos_Obj_4" (type: "Objects")
       + AudioChannelFormat (AC_00031004) "Atmos_Obj_4"
         -> AudioStreamFormat (AS_00031004)

```
