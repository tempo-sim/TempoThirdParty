# Eigen3Config.cmake

# Get the directory where this file is located
get_filename_component(PKGCONFIG_CMAKE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)

# Calculate the installation prefix relative to this file
get_filename_component(INSTALL_PREFIX "${PKGCONFIG_CMAKE_DIR}/../install" ABSOLUTE)

# Set the include directory
set(Eigen3_INCLUDE_DIR "C:\\rclbld\\eigen-cp")

# Set the version
set(Eigen3_VERSION "1.12.2")

# Create an imported target for Eigen3
if(NOT TARGET Eigen3::Eigen3)
    add_library(Eigen3::Eigen3 INTERFACE IMPORTED)
    set_target_properties(Eigen3::Eigen3 PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${Eigen3_INCLUDE_DIR}"
    )
endif()

# Provide standard find_package() interface variables
set(Eigen3_FOUND TRUE)
set(Eigen3_INCLUDE_DIRS ${Eigen3_INCLUDE_DIR})
set(Eigen3_LIBRARIES Eigen3::Eigen3)
