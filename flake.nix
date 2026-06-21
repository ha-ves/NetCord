{
  description = ".NET env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
  let
    supportedArch = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    forAllArch = nixpkgs.lib.genAttrs supportedArch;
  in
  {
    devShells = forAllArch (arch:
      let
        pkgs = nixpkgs.legacyPackages.${arch};

        globalJson = builtins.fromJSON (builtins.readFile ./global.json);
        version = builtins.splitVersion globalJson.sdk.version;

        major = builtins.elemAt version 0;
        minor = builtins.elemAt version 1;

        dotnet = pkgs.dotnetCorePackages."sdk_${major}_${minor}-bin";

        docfx = pkgs.buildDotnetGlobalTool {
          pname = "docfx";
          version = "2.78.3";
          nugetHash = "sha256-hLb6OmxqXOOxFaq/N+aZ0sAzEYjU0giX3c1SWQtKDbs=";
          dotnet-sdk = dotnet;
        };

        dotnetRoot = "${dotnet.unwrapped}/share/dotnet";

        # Use the full darwin.apple_sdk instead of apple-sdk_14
        darwinPackages = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin (with pkgs; [
          libiconv
          darwin.apple_sdk
        ]);

        # Compute SDKROOT in a let binding, not inside mkShell
        sdkRoot = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin
          "${pkgs.darwin.apple_sdk}/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk";
      in
      {
        default = pkgs.mkShell {
          packages = [
            dotnet
          ];

          DOTNET_ROOT = dotnetRoot;
        };

        natives = pkgs.mkShell {
          packages = [
            dotnet
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
            pkgs.autoconf
            pkgs.autoconf-archive
            pkgs.automake
            pkgs.libtool
          ] ++ darwinPackages;

          DOTNET_ROOT = dotnetRoot;

          # Use the precomputed sdkRoot, not SDKROOT
          SDKROOT = sdkRoot;

          NIX_CFLAGS_COMPILE = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin
            "-isysroot ${sdkRoot}";

          shellHook = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
            export SDKROOT="${sdkRoot}"
            export LDFLAGS="-F$SDKROOT/System/Library/Frameworks -L$SDKROOT/usr/lib"
            export NIX_LDFLAGS="-F$SDKROOT/System/Library/Frameworks -L$SDKROOT/usr/lib"
            export NIX_CFLAGS_COMPILE="-isysroot $SDKROOT"
            export NIX_CPPFLAGS="-isysroot $SDKROOT"
          '';
        };

        docs = pkgs.mkShell {
          packages = [
            docfx
            dotnet
            pkgs.nodejs_26
          ];

          DOTNET_ROOT = dotnetRoot;
        };
      }
    );
  };
}
