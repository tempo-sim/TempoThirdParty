# Force ROS libraries to build and link against Unreal's OpenSSL

set(UE_THIRD_PARTY_PATH "$ENV{UE_THIRD_PARTY_PATH}")

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG OFF)

set(OPENSSL_FOUND TRUE)
set(OPENSSL_ROOT_DIR "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t")
set(OPENSSL_USE_STATIC_LIBS TRUE)
set(OPENSSL_INCLUDE_DIR "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/include/Win64/VS2015")
set(OPENSSL_CRYPTO_LIBRARY "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libcrypto.lib")
SET(OPENSSL_SSL_LIBRARY "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libssl.lib")
# Unreal's OpenSSL is static, so every consumer has to link the Windows system libraries libcrypto
# depends on. crypt32 is what its CAPI engine (e_capi.obj) needs; without it a link against
# OpenSSL::Crypto fails with unresolved __imp_Cert* symbols. Unreal's own OpenSSL.Build.cs adds
# crypt32 for the same reason, and ws2_32 is what CMake's builtin FindOpenSSL adds on Windows.
SET(OPENSSL_SYSTEM_LIBRARIES crypt32 ws2_32)

# A CMake list is ";"-separated. Joining these with a space instead produces a single nonexistent
# path, which silently drops OpenSSL for any consumer that links ${OPENSSL_LIBRARIES} directly
# rather than through the imported targets below.
SET(OPENSSL_LIBRARIES "${OPENSSL_SSL_LIBRARY};${OPENSSL_CRYPTO_LIBRARY};${OPENSSL_SYSTEM_LIBRARIES}")
SET(OPENSSL_VERSION "1.1.1t")

if(NOT TARGET OpenSSL::Crypto)
    add_library(OpenSSL::Crypto STATIC IMPORTED)
endif()
set_target_properties(OpenSSL::Crypto PROPERTIES
    IMPORTED_LOCATION "${OPENSSL_CRYPTO_LIBRARY}"
    IMPORTED_LINK_INTERFACE_LANGUAGES "C"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${OPENSSL_SYSTEM_LIBRARIES}")

# Targets that link only OpenSSL::SSL (dds_security_auth, dds_security_ac, ...) still need the
# symbols in libcrypto, so declare that dependency the way CMake's builtin FindOpenSSL does.
if(NOT TARGET OpenSSL::SSL)
    add_library(OpenSSL::SSL STATIC IMPORTED)
endif()
set_target_properties(OpenSSL::SSL PROPERTIES
    IMPORTED_LOCATION "${OPENSSL_SSL_LIBRARY}"
    IMPORTED_LINK_INTERFACE_LANGUAGES "C"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "OpenSSL::Crypto")
