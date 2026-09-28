# TempoThirdParty
Tempo's third party dependencies

## gRPC

`Scripts/build_grpc_<platform>.sh` builds gRPC, Protobuf and Abseil as static libraries against the
Unreal Engine's OpenSSL and zlib (`UNREAL_ENGINE_PATH` must point at the engine), then links them
whole into one shared library, `tempogrpc` (`Utils/tempogrpc`). Tempo's modules all share that one
copy of the libraries, which keeps their global state (Protobuf's descriptor pool, gRPC's core) from
being duplicated across modules. `Patches/gRPC.patch` builds the grpc++ libraries with default
visibility so the shared library can export gRPC's C++ API, which is not annotated for export.

The Linux build is a cross-compile from Windows, run after the Windows build.
