{ pkgs, ... }: {
  # Which nixpkgs to use.
  channel = "stable-23.11";
  packages = [
    pkgs.jdk17
    pkgs.unzip
    pkgs.nodePackages.firebase-tools
  ];
  # Sets environment variables in the workspace
  env = {};
  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];
    workspace = {
      # Runs when a workspace is first created with this `dev.nix` file
      onCreate = {
        build-flutter = ''
          # Execute web build in debug mode.
          # flutter run does this transparently either way
          # https://github.com/flutter/flutter/issues/96283#issuecomment-1144750411
          # flutter build web --profile --dart-define=Dart2jsOptimization=O0 

          adb -s localhost:5555 wait-for-device
        '';
      };
      
      # To run something each time the workspace is (re)started, use the `onStart` hook
    };
    # Enable previews and customize configuration
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["flutter" "run" "--machine" "-d" "web-server" "--web-hostname" "0.0.0.0" "--web-port" "$PORT" "--web-renderer" "html"];
          manager = "flutter";
        };
        android = {
          command = ["flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555"];
          manager = "flutter";
        };
      };
    };
  };
}