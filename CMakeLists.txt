# Set the minimum required version of CMake
cmake_minimum_required(VERSION 3.22)

# Set the project name and language
project(jniPdfium LANGUAGES CXX)

message(STATUS "ANDROID_NDK: ${ANDROID_NDK}")
message(STATUS "CMAKE_ANDROID_NDK: ${CMAKE_ANDROID_NDK}")
message(STATUS "CMAKE_SYSTEM_NAME: ${CMAKE_SYSTEM_NAME}")
message(STATUS "CMAKE_ANDROID_ARCH_ABI: ${CMAKE_ANDROID_ARCH_ABI}")
message(STATUS "ANDROID_ABI: ${ANDROID_ABI}")
message(STATUS "ANDROID_PLATFORM: ${ANDROID_PLATFORM}")

# Where Gradle prepares prebuilt shared libs (libmodft2/libmodpng/libmodpdfium) per ABI.
# Fallback to the legacy repo path for compatibility.
if(NOT DEFINED PDFIUMANDROID_PREBUILT_DIR OR "${PDFIUMANDROID_PREBUILT_DIR}" STREQUAL "")
    set(PDFIUMANDROID_PREBUILT_DIR "${CMAKE_SOURCE_DIR}/src/main/jni/lib")
endif()

message(STATUS "PDFIUMANDROID_PREBUILT_DIR: ${PDFIUMANDROID_PREBUILT_DIR}")


# Add the source files for the library
set(SOURCES
        src/main/jni/src/mainJNILib.cpp
        src/main/jni/src/util.hpp
)

# Create the shared library target
add_library(jniPdfium SHARED ${SOURCES})

# Specify include directories if necessary
target_include_directories(jniPdfium
        PRIVATE ${CMAKE_SOURCE_DIR}/src/main/jni/include
)

# Import prebuilt libraries
add_library(modft2 SHARED IMPORTED)
set_target_properties(modft2 PROPERTIES IMPORTED_LOCATION
        ${PDFIUMANDROID_PREBUILT_DIR}/${ANDROID_ABI}/libmodft2.so)

add_library(modpdfium SHARED IMPORTED)
set_target_properties(modpdfium PROPERTIES IMPORTED_LOCATION
        ${PDFIUMANDROID_PREBUILT_DIR}/${ANDROID_ABI}/libmodpdfium.so)

add_library(modpng SHARED IMPORTED)
set_target_properties(modpng PROPERTIES IMPORTED_LOCATION
        ${PDFIUMANDROID_PREBUILT_DIR}/${ANDROID_ABI}/libmodpng.so)

# Specify the dependent dynamic libraries to link against
target_link_libraries(jniPdfium
        PRIVATE modft2
        PRIVATE modpdfium
        PRIVATE modpng
)

# Force correct PT_LOAD alignment for modpdfium on all ABIs
set_target_properties(jniPdfium PROPERTIES
    LINK_FLAGS "-Wl,-z,max-page-size=0x4000"
)

# Specify additional compile options if required
target_compile_options(jniPdfium PRIVATE
        -Wall -Wextra -DHAVE_PTHREADS
)

# Specify additional linker flags if necessary
target_link_options(jniPdfium PRIVATE
        -Wl,--no-undefined -llog -landroid -ljnigraphics
)

# Copy prebuilt libraries to output directory
add_custom_command(TARGET jniPdfium POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${PDFIUMANDROID_PREBUILT_DIR}/${ANDROID_ABI}/libmodft2.so
        $<TARGET_FILE_DIR:jniPdfium>/libmodft2.so
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${PDFIUMANDROID_PREBUILT_DIR}/${ANDROID_ABI}/libmodpdfium.so
        $<TARGET_FILE_DIR:jniPdfium>/libmodpdfium.so
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${PDFIUMANDROID_PREBUILT_DIR}/${ANDROID_ABI}/libmodpng.so
        $<TARGET_FILE_DIR:jniPdfium>/libmodpng.so
        COMMENT "Copying prebuilt libraries to output directory"
)
