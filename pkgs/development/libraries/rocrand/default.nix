{ lib
, stdenv
, fetchFromGitHub
, writeScript
, cmake
, rocm-cmake
, rocm-runtime
, rocm-device-libs
, rocm-comgr
, hip
, gtest
, gbenchmark
, buildTests ? false
, buildBenchmarks ? false
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "rocrand";
  version = "5.3.3";

  outputs = [
    "out"
  ] ++ lib.optionals buildTests [
    "test"
  ] ++ lib.optionals buildBenchmarks [
    "benchmark"
  ];

  src = fetchFromGitHub {
    owner = "ROCmSoftwarePlatform";
    repo = "rocRAND";
    rev = "rocm-${finalAttrs.version}";
    hash = "sha256-awQLqPmhVxegrqqSoC8fiCQJ33bPKZlljSAXnHVcIZo=";
    fetchSubmodules = true; # For inline hipRAND
  };

  nativeBuildInputs = [
    cmake
    rocm-cmake
    hip
  ];

  buildInputs = [
    rocm-runtime
    rocm-device-libs
    rocm-comgr
  ] ++ lib.optionals buildTests [
    gtest
  ] ++ lib.optionals buildBenchmarks [
    gbenchmark
  ];

  cmakeFlags = [
    "-DCMAKE_C_COMPILER=hipcc"
    "-DCMAKE_CXX_COMPILER=hipcc"
    "-DHIP_ROOT_DIR=${hip}"
    # Manually define CMAKE_INSTALL_<DIR>
    # See: https://github.com/NixOS/nixpkgs/pull/197838
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
  ] ++ lib.optionals buildTests [
    "-DBUILD_TEST=ON"
  ] ++ lib.optionals buildBenchmarks [
    "-DBUILD_BENCHMARK=ON"
  ];

  postInstall = lib.optionalString buildTests ''
    mkdir -p $test/bin
    mv $out/bin/test_* $test/bin
  '' + lib.optionalString buildBenchmarks ''
    mkdir -p $benchmark/bin
    mv $out/bin/benchmark_* $benchmark/bin
  '' + lib.optionalString (buildTests || buildBenchmarks) ''
    rmdir $out/bin
  '';

  passthru.updateScript = writeScript "update.sh" ''
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p curl jq common-updater-scripts
    version="$(curl ''${GITHUB_TOKEN:+"-u \":$GITHUB_TOKEN\""} \
      -sL "https://api.github.com/repos/ROCmSoftwarePlatform/rocRAND/releases?per_page=1" | jq '.[0].tag_name | split("-") | .[1]' --raw-output)"
    update-source-version rocrand "$version" --ignore-same-hash
  '';

  meta = with lib; {
    description = "Generate pseudo-random and quasi-random numbers";
    homepage = "https://github.com/ROCmSoftwarePlatform/rocRAND";
    license = with licenses; [ mit ];
    maintainers = teams.rocm.members;
    broken = finalAttrs.version != hip.version;
  };
})
