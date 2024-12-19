{
  lib,
  stdenv,
  requireFile,
  autoPatchelfHook,
  undmg,
  fetchurl,
  makeDesktopItem,
  copyDesktopItems,
  libarchive,
  imagemagick,
  runCommand,
  libgcc,
  wxGTK32,
  libGL,
  SDL2,
  openal,
  libmpg123,
  libxmp,
}:

let
  version = "469d";
  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v${version}/OldUnreal-UTPatch${version}-Linux-amd64.tar.bz2";
      hash = "sha256-aoGzWuakwN/OL4+xUq8WEpd2c1rrNN/DkffI2vDVGjs=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v${version}/OldUnreal-UTPatch${version}-Linux-arm64.tar.bz2";
      hash = "sha256-2e9lHB12jLTR8UYofLWL7gg0qb2IqFk6eND3T5VqAx0=";
    };
    i686-linux = fetchurl {
      url = "https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v${version}/OldUnreal-UTPatch${version}-Linux-x86.tar.bz2";
      hash = "sha256-1JsFKuAAj/LtYvOUPFu0Hn+zvY3riW0YlJbLd4UnaKU=";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v${version}/OldUnreal-UTPatch${version}-macOS-Sonoma.dmg";
      hash = "sha256-TbhJbOH4E5WOb6XR9dmqLkXziK3/CzhNjd1ypBkkmvw=";
    };
  };
  unpackIso =
    runCommand "ut1999-iso"
      {
        src = fetchurl {
          url = "https://archive.org/download/ut-goty/UT_GOTY_CD1.iso";
          hash = "sha256-4YSYTKiPABxd3VIDXXbNZOJm4mx0l1Fhte1yNmx0cE8=";
        };
        nativeBuildInputs = [ libarchive ];
      }
      ''
        bsdtar -xvf "$src"
        mkdir $out
        cp -r Music Sounds Textures Maps $out
      '';
  # TODO: find stable icon source
  getIcon =
    runCommand "ut1999-ico"
      {
        src = fetchurl {
          url = "https://cdn2.steamgriddb.com/icon/3edadc22520518c0d5d4580cf9af3a8c.ico";
          hash = "sha256-Dcs1jJbv2mmC2qokJbN0Umjpxa9w0wX9Eb45xZ2v08A=";
        };
        nativeBuildInputs = [ imagemagick ];
      }
      ''
        convert $src ut1999.png
        mkdir $out
        cp ut1999-*.png $out
      '';
  systemDir =
    {
      x86_64-linux = "System64";
      aarch64-linux = "SystemARM64";
      x86_64-darwin = "System";
      i686-linux = "System";
    }
    .${stdenv.hostPlatform.system} or (throw "unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  name = "ut1999";
  inherit version;
  sourceRoot = ".";
  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  buildInputs = [
    libgcc
    wxGTK32
    SDL2
    libGL
    openal
    libmpg123
    libxmp
    stdenv.cc.cc
  ];

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      copyDesktopItems
      autoPatchelfHook
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      undmg
    ];

  installPhase =
    let
      outPrefix =
        if stdenv.hostPlatform.isDarwin then "$out/UnrealTournament.app/Contents/MacOS" else "$out";
    in
    ''
      runHook preInstall

      mkdir -p $out/bin
      cp -r ${if stdenv.hostPlatform.isDarwin then "UnrealTournament.app" else "./*"} $out
      chmod -R 755 $out
      cd ${outPrefix}

      # NOTE: OldUnreal patch doesn't include these folders but could in the future
      rm -rf ./{Music,Sounds,Maps}
      ln -s ${unpackIso}/{Music,Sounds,Maps} .

      # TODO: unpack compressed maps with ucc

      cp -n ${unpackIso}/Textures/* ./Textures || true
      cp -n ${unpackIso}/System/*.{u,int} ./System || true
    ''
    + lib.optionalString (stdenv.hostPlatform.isLinux) ''
      ln -s "$out/${systemDir}/ut-bin" "$out/bin/ut1999"
      ln -s "$out/${systemDir}/ucc-bin" "$out/bin/ut1999-ucc"

      install -D "${getIcon}/ut1999-0.png" "$out/share/icons/hicolor/16x16/apps/ut1999.png"
      install -D "${getIcon}/ut1999-1.png" "$out/share/icons/hicolor/24x24/apps/ut1999.png"
      install -D "${getIcon}/ut1999-2.png" "$out/share/icons/hicolor/32x32/apps/ut1999.png"
      install -D "${getIcon}/ut1999-3.png" "$out/share/icons/hicolor/48x48/apps/ut1999.png"
      install -D "${getIcon}/ut1999-4.png" "$out/share/icons/hicolor/64x64/apps/ut1999.png"
      install -D "${getIcon}/ut1999-5.png" "$out/share/icons/hicolor/128x128/apps/ut1999.png"
      install -D "${getIcon}/ut1999-6.png" "$out/share/icons/hicolor/192x192/apps/ut1999.png"
      install -D "${getIcon}/ut1999-7.png" "$out/share/icons/hicolor/256x256/apps/ut1999.png"

      # Remove bundled libraries to use native versions instead
      rm $out/${systemDir}/libmpg123.so* \
        $out/${systemDir}/libopenal.so* \
        $out/${systemDir}/libSDL2* \
        $out/${systemDir}/libxmp.so*
        # NOTE: what about fmod?
        #$out/${systemDir}/libfmod.so*
    ''
    + ''
      runHook postInstall
    '';

  # Bring in game's .so files into lookup. Otherwise game fails to start
  # as: `Object not found: Class Render.Render`
  appendRunpaths = [
    "${placeholder "out"}/${systemDir}"
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "ut1999";
      desktopName = "Unreal Tournament GOTY (1999)";
      exec = "ut1999";
      icon = "ut1999";
      comment = "Unreal Tournament GOTY (1999) with the OldUnreal patch.";
      categories = [ "Game" ];
    })
  ];

  meta = with lib; {
    description = "Unreal Tournament GOTY (1999) with the OldUnreal patch";
    license = licenses.unfree;
    platforms = attrNames srcs;
    maintainers = with maintainers; [ eliandoran ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "ut1999";
  };
}

