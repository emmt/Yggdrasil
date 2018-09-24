include("../common.jl")

compiler_target = nothing
try
    global compiler_target = triplet(platform_key(ARGS[end]))
    if typeof(compiler_target) <:UnknownPlatform
        error()
    end
catch
    error("This is not a typical build_tarballs.jl!  Must provide exactly one platform as the last argument!")
end

name = "BaseCompilerShard-$(compiler_target)"
version = v"2018.09.18"

# We're going to install things into this prefix, then package it up as a .tar.gz
temp_prefix() do prefix
    # Install KernelHeaders
    headers_path = find_tarball("KernelHeaders", "KernelHeaders.*$(compiler_target)").url
    @info("Unpacking $(headers_path)")
    unpack(headers_path, prefix.path)

    # Install Binutils
    binutils_path = find_tarball("Binutils", "Binutils-$(compiler_target)").url
    @info("Unpacking $(binutils_path)")
    unpack(binutils_path, prefix.path)

    # Install Libc
    libc_path = ""
    if occursin("-gnu", compiler_target)
        # If we're a `-gnu` target, install Glibc.  We install version 2.17 on
        # x86_64 and i686, 2.19 on armv7l and aarch64, and 2.25 on ppc64le. These
        # versions are chosen through the time-tested method of "pick the earliest
        # one that works", so as to maximize compatibility.  We also do our best
        # to match versions of official Julia binaries.
        glibc_version_dict = Dict(
            :x86_64 => "2.17",
            :i686 => "2.17",
            :aarch64 => "2.19",
            :armv7l => "2.19",
            :powerpc64le => "2.25",
        )
        glibc_version = glibc_version_dict[arch(platform_key(compiler_target))]

        libc_path = find_tarball("Glibc", "Glibc.*$(glibc_version).*$(compiler_target)").url
    elseif occursin("-musl", compiler_target)
        libc_path = find_tarball("Musl", "Musl.*$(compiler_target)").url
    elseif occursin("-mingw", compiler_target)
        libc_path = find_tarball("Mingw", "Mingw.*$(compiler_target)").url
    elseif occursin("-freebsd", compiler_target)
        libc_path = find_tarball("FreeBSDLibc", "FreeBSDLibc.*").url
    elseif occursin("-darwin", compiler_target)
        libc_path = find_tarball("MacOSLibc", "MacOSLibc.*").url
    else
        error("Don't know how to install a Libc for $(compiler_target)!")
    end
    @info("Unpacking $(libc_path)")
    unpack(libc_path, prefix.path)

    # Deploy our cmake toolchain files
    toolchain_dir = joinpath(@__DIR__, "cmake_toolchains", "$(compiler_target)")
    for f in readdir(toolchain_dir)
        cp(joinpath(toolchain_dir, f), joinpath(prefix.path, f))
    end

    # Do a little bit of cleanup; at this point we don't care about logs, manifests, etc...
    rm(joinpath(prefix, "logs"); recursive=true, force=true)
    rm(joinpath(prefix, "manifests"); recursive=true, force=true)

    # Package this prefix up nice and tight
    mkpath(joinpath(pwd(), "products"))
    out_path = joinpath(pwd(), "products", name)
    package(prefix, out_path, version; platform=Linux(:x86_64, :glibc), verbose=true, force=true)
end
