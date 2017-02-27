# Centralized place to define OpenBLAS variables 
# Sets the following variables:
#
# General information:
# BLAS_FOUND
#
# Settings for compiling against OpenBLAS libraries:
# BLAS_INCLUDE_DIRS
# BLAS_LIBS
# BLAS_DLL_DIR
#
# Using FindBLAS module:
# find_package(BLAS)
# if(BLAS_FOUND)
#     message(STATUS "Blas libraries: ${BLAS_LIBRARIES}")
#     message(STATUS "Blas linker flags: ${BLAS_LINKER_FLAGS}")
#     message(STATUS "Blas vendor: ${BLA_VENDOR}")
#
# Variables defined by FindBLAS module that we don't set:
#     BLAS_LIBRARIES
#     BLAS_LINKER_FLAGS
#     BLA_VENDOR

# Include guard so we don't try to find or download BLAS more than once
if(BLASSetup_included)
    return()
endif()
set(BLASSetup_included true)

# Set policy saying to use newish IN_LIST operator
cmake_policy(SET CMP0057 NEW)

# Map of processor name -> OpenBLAS version to use
macro(set_processor_mapping _processor_generation _openblas_version)
  set("processor_map_${_processor_generation}" "${_openblas_version}")
endmacro()

macro(get_processor_mapping _result _processor_generation)
    if(DEFINED processor_map_${_processor_generation})
        set(${_result} ${processor_map_${_processor_generation}})
    else()
        set(${_result} ${_processor_generation})
    endif()
endmacro()

set(BLAS_INCLUDE_SEARCH_PATHS )
set(BLAS_LIB_SEARCH_PATHS )
set(BLAS_LIB_NAMES cblas openblas libopenblas.dll.a)

find_package(BLAS QUIET)
if(BLAS_FOUND)
    message(STATUS "Blas libraries: ${BLAS_LIBRARIES}")
    message(STATUS "Blas linker flags: ${BLAS_LINKER_FLAGS}")
    message(STATUS "Blas include directories: ${BLAS_INCLUDE_DIRS}")
    set(BLAS_LIBS ${BLAS_LIBRARIES})
else()
    if(WIN32)

        # Known registry ID (family, model) settings for various CPU types
        #
        # Haswell: Family 6, model 60, 63, 69, 70
        # Sandybridge: Family 6, model 42, 45
        # Skylake: Family 6, model 78

        # We can set up a mapping from a detected processor generation to the version of
        # the OpenBLAS libraries to use with the set_processor_mapping macro. For instance,
        # if we want to use the haswell libraries on skylake processors, add the following:
        #
        # set_processor_mapping("skylake" "haswell")

        # Determine CPU type
        set(supported_processors "haswell") # The list of processor-specific versions of OpenBLAS available in the package

        get_filename_component(processor_id "[HKEY_LOCAL_MACHINE\\Hardware\\Description\\System\\CentralProcessor\\0;Identifier]" ABSOLUTE)
        string(REGEX REPLACE ".* Family ([0-9]+) .*" "\\1" processor_family "${processor_id}")
        string(REGEX REPLACE ".* Model ([0-9]+) .*" "\\1" processor_model "${processor_id}")
        message(STATUS "Processor family: ${processor_family}, model: ${processor_model}")

        set(PROCESSOR_HINT auto CACHE STRING "Processor detection hint (haswell | auto)")
        if(${PROCESSOR_HINT} STREQUAL "auto")
            if(processor_family EQUAL 6)
                if(processor_model EQUAL 60 OR processor_model EQUAL 63 OR processor_model EQUAL 69 OR processor_model EQUAL 70)
                    set(processor_generation "haswell")
                elseif(processor_model EQUAL 42 OR processor_model EQUAL 45)
                    set(processor_generation "sandybridge")
                elseif(processor_model EQUAL 42 OR processor_model EQUAL 78)
                    set(processor_generation "skylake")
                endif()
            endif()
        else()
            set(processor_generation "${PROCESSOR_HINT}")
        endif()
        
        set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES} ".dll.a" ".a")
        set(processor_to_use "")
        get_processor_mapping(processor_to_use ${processor_generation})
        if("${processor_to_use}" IN_LIST supported_processors)
            message(STATUS "Using OpenBLAS compiled for ${processor_generation}")
            set(BLAS_PACKAGE_NAME "OpenBLASLibs")
            set(BLAS_PACKAGE_VERSION 0.2.19.2)
            set(BLAS_PACKAGE_DIR ${PACKAGE_ROOT}/${BLAS_PACKAGE_NAME}.${BLAS_PACKAGE_VERSION}/build/native/x64/${processor_generation})
            set(BLAS_DLLS libopenblas.dll libgcc_s_seh-1.dll libgfortran-3.dll libquadmath-0.dll)
            set(BLAS_DLL_DIR ${BLAS_PACKAGE_DIR}/bin)
            set(BLAS_INCLUDE_SEARCH_PATHS ${BLAS_PACKAGE_DIR}/include/)
            set(BLAS_LIB_SEARCH_PATHS ${BLAS_PACKAGE_DIR}/lib/)    
        else()
            message(STATUS "Unknown processor, disabling OpenBLAS")
        endif()
    endif()
endif()

if(NOT WIN32)
    ## Note: libopenblas installs on ubuntu in /usr/lib and /usr/include
    set(BLAS_INCLUDE_SEARCH_PATHS
        /System/Library/Frameworks/Accelerate.framework/Versions/Current/Frameworks/vecLib.framework/Versions/Current/Headers/
        /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Accelerate.framework/Frameworks/vecLib.framework/Headers/
        /usr/include
        /usr/local/include
    )

    set(BLAS_LIB_SEARCH_PATHS
        /usr/lib64/atlas-sse3 /usr/lib64/atlas /usr/lib64 /usr/local/lib64/atlas /usr/local/lib64 /usr/lib/atlas-sse3 /usr/lib/atlas-sse2 /usr/lib/atlas-sse /usr/lib/atlas-3dnow /usr/lib/atlas /usr/lib /usr/local/lib/atlas /usr/local/lib
    )
endif()

find_path(BLAS_INCLUDE_DIRS cblas.h
    PATHS ${BLAS_INCLUDE_SEARCH_PATHS} ${BLAS_INCLUDE_DIRS}
    NO_DEFAULT_PATH
)

find_library(BLAS_LIBS
    NAMES ${BLAS_LIB_NAMES}
    PATHS ${BLAS_LIB_SEARCH_PATHS}
    NO_DEFAULT_PATH
)

if(BLAS_LIBS AND BLAS_INCLUDE_DIRS)
    message(STATUS "Using BLAS include path: ${BLAS_INCLUDE_DIRS}")
    message(STATUS "Using BLAS library: ${BLAS_LIBS}")
    message(STATUS "Using BLAS DLLs: ${BLAS_DLLS}")
    set(BLAS_FOUND "YES")
else()
    message(STATUS "BLAS library not found")
    set(BLAS_INCLUDE_DIRS "")
    set(BLAS_LIBS "")
    set(BLAS_FOUND "NO")
endif()