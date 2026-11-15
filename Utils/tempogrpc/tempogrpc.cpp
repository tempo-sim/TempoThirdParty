// Copyright Tempo Simulation, LLC. All Rights Reserved

// tempogrpc's code all comes from the static libraries it links, apart from one thing: on Windows, the
// allocator behind its operator new and delete.
//
// Every Unreal module replaces operator new and delete with its own definitions, which call
// FMemory (ModuleBoilerplate.h). A Windows DLL gets its operators from whatever it links, so without
// the definitions below this library would use the CRT heap, and the two would share objects they
// cannot free. Protobuf's string fields are the common case. ArenaStringPtr::Mutable and Destroy run
// in here, but std::string::resize is a header template that compiles into the module calling it. So
// a module that resizes a field puts an FMemory buffer in a std::string that this library then hands
// to the CRT's free, and the process dies with STATUS_HEAP_CORRUPTION (0xC0000374). Strings returned
// by value go the other way: allocated here, freed by FMemory.
//
// So, when it is loaded into an Unreal process, this library allocates the way an Unreal module does,
// through the FMemory the process's Core module exports. Elsewhere (Tempo's C++ client), Core is not
// loaded, and it uses the CRT as before. The choice is made once, at the first allocation, and never
// changes, so nothing is ever freed by an allocator other than the one that made it. Core is always
// loaded before any plugin module, and therefore before this library.
//
// A monolithic (packaged) build is unaffected: it links the static libraries into the executable
// instead of loading this library, so the executable's one operator new serves both. Linux and macOS
// are left as they were; the tests that expose this pass there.

#if defined(_WIN32)

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#ifndef PSAPI_VERSION
#define PSAPI_VERSION 2  // EnumProcessModules is K32EnumProcessModules, in kernel32: no psapi.lib
#endif
#include <windows.h>
#include <psapi.h>

#include <cstdint>
#include <cstdlib>
#include <malloc.h>
#include <new>

namespace
{
	// FMemory::Malloc(SIZE_T Count, uint32 Alignment) and FMemory::Free(void* Original), CORE_API statics.
	using FMemoryMallocFn = void* (*)(size_t, uint32_t);
	using FMemoryFreeFn = void (*)(void*);
	constexpr const char* FMemoryMallocSymbol = "?Malloc@FMemory@@SAPEAX_KI@Z";
	constexpr const char* FMemoryFreeSymbol = "?Free@FMemory@@SAXPEAX@Z";

	// Null until resolved, and null for good where no Unreal Core is loaded.
	FMemoryMallocFn GMalloc = nullptr;
	FMemoryFreeFn GFree = nullptr;
	INIT_ONCE GResolveOnce = INIT_ONCE_STATIC_INIT;

	// Looks for the module exporting FMemory, whatever it is named (UnrealEditor-Core.dll,
	// UnrealGame-Core.dll, a -Win64-Debug variant...). Must not allocate: it runs inside the first
	// operator new, usually under the loader lock while this library's static initializers run.
	BOOL CALLBACK ResolveAllocator(PINIT_ONCE, PVOID, PVOID*)
	{
		static HMODULE Modules[8192];
		DWORD BytesNeeded = 0;
		if (!EnumProcessModules(GetCurrentProcess(), Modules, sizeof(Modules), &BytesNeeded))
		{
			return TRUE;
		}
		const DWORD NumModules = (BytesNeeded < sizeof(Modules) ? BytesNeeded : sizeof(Modules)) / sizeof(HMODULE);
		for (DWORD Index = 0; Index < NumModules; ++Index)
		{
			const FARPROC Malloc = GetProcAddress(Modules[Index], FMemoryMallocSymbol);
			const FARPROC Free = Malloc ? GetProcAddress(Modules[Index], FMemoryFreeSymbol) : nullptr;
			if (Malloc && Free)
			{
				GMalloc = reinterpret_cast<FMemoryMallocFn>(Malloc);
				GFree = reinterpret_cast<FMemoryFreeFn>(Free);
				break;
			}
		}
		return TRUE;
	}

	bool UseFMemory()
	{
		InitOnceExecuteOnce(&GResolveOnce, ResolveAllocator, nullptr, nullptr);
		return GMalloc != nullptr;
	}

	// Default alignment exactly as Unreal's replacement operator new chooses it.
	size_t DefaultAlignment(size_t Size)
	{
		return Size <= 8 ? 8 : __STDCPP_DEFAULT_NEW_ALIGNMENT__;
	}

	// Returns null on failure.
	void* Allocate(size_t Size, size_t Alignment, bool bAligned)
	{
		Size = Size ? Size : 1;
		if (UseFMemory())
		{
			return GMalloc(Size, static_cast<uint32_t>(Alignment));
		}
		return bAligned ? _aligned_malloc(Size, Alignment) : std::malloc(Size);
	}

	void Deallocate(void* Ptr, bool bAligned)
	{
		if (!Ptr)
		{
			return;
		}
		if (UseFMemory())
		{
			GFree(Ptr);
		}
		else if (bAligned)
		{
			_aligned_free(Ptr);
		}
		else
		{
			std::free(Ptr);
		}
	}

	void* AllocateOrThrow(size_t Size, size_t Alignment, bool bAligned)
	{
		if (void* Ptr = Allocate(Size, Alignment, bAligned))
		{
			return Ptr;
		}
		throw std::bad_alloc();
	}
}

void* operator new  (size_t Size)                                                             { return AllocateOrThrow(Size, DefaultAlignment(Size), false); }
void* operator new[](size_t Size)                                                             { return AllocateOrThrow(Size, DefaultAlignment(Size), false); }
void* operator new  (size_t Size, const std::nothrow_t&) noexcept                             { return Allocate(Size, DefaultAlignment(Size), false); }
void* operator new[](size_t Size, const std::nothrow_t&) noexcept                             { return Allocate(Size, DefaultAlignment(Size), false); }
void* operator new  (size_t Size, std::align_val_t Alignment)                                 { return AllocateOrThrow(Size, static_cast<size_t>(Alignment), true); }
void* operator new[](size_t Size, std::align_val_t Alignment)                                 { return AllocateOrThrow(Size, static_cast<size_t>(Alignment), true); }
void* operator new  (size_t Size, std::align_val_t Alignment, const std::nothrow_t&) noexcept { return Allocate(Size, static_cast<size_t>(Alignment), true); }
void* operator new[](size_t Size, std::align_val_t Alignment, const std::nothrow_t&) noexcept { return Allocate(Size, static_cast<size_t>(Alignment), true); }

void operator delete  (void* Ptr) noexcept                                          { Deallocate(Ptr, false); }
void operator delete[](void* Ptr) noexcept                                          { Deallocate(Ptr, false); }
void operator delete  (void* Ptr, const std::nothrow_t&) noexcept                   { Deallocate(Ptr, false); }
void operator delete[](void* Ptr, const std::nothrow_t&) noexcept                   { Deallocate(Ptr, false); }
void operator delete  (void* Ptr, size_t) noexcept                                  { Deallocate(Ptr, false); }
void operator delete[](void* Ptr, size_t) noexcept                                  { Deallocate(Ptr, false); }
void operator delete  (void* Ptr, std::align_val_t) noexcept                        { Deallocate(Ptr, true); }
void operator delete[](void* Ptr, std::align_val_t) noexcept                        { Deallocate(Ptr, true); }
void operator delete  (void* Ptr, std::align_val_t, const std::nothrow_t&) noexcept { Deallocate(Ptr, true); }
void operator delete[](void* Ptr, std::align_val_t, const std::nothrow_t&) noexcept { Deallocate(Ptr, true); }
void operator delete  (void* Ptr, size_t, std::align_val_t) noexcept                { Deallocate(Ptr, true); }
void operator delete[](void* Ptr, size_t, std::align_val_t) noexcept                { Deallocate(Ptr, true); }

#endif // _WIN32
