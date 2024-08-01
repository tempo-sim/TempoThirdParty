# AsioConfig.cmake

# Get the directory where this file is located
get_filename_component(ASIO_CMAKE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)

# Calculate the installation prefix relative to this file
get_filename_component(ASIO_INSTALL_PREFIX "${ASIO_CMAKE_DIR}/../install" ABSOLUTE)

# Set the include directory
set(Asio_INCLUDE_DIR "${ASIO_INSTALL_PREFIX}/include/asio")

# Set the version
set(Asio_VERSION "1.12.2")

# Create an imported target for Asio
if(NOT TARGET Asio::Asio)
    add_library(Asio::Asio INTERFACE IMPORTED)
    set_target_properties(Asio::Asio PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${Asio_INCLUDE_DIR}"
    )
endif()

# Provide standard find_package() interface variables
set(Asio_FOUND TRUE)
set(Asio_INCLUDE_DIRS ${ASIO_INCLUDE_DIR})
set(Asio_LIBRARIES Asio::Asio)
