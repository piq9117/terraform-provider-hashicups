{
  description = "Basic go template";

  inputs.nixpkgs.url = "nixpkgs/nixos-22.05";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [];
      });
      OS_LINUX_ARCH = "linux_amd64";

    in {overlay = final: prev: {};
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          go = pkgs.go_1_18;
        in {
          build-all = pkgs.writeShellScriptBin "build-all" ''
            GITROOT=$(git rev-parse --show-toplevel)
            ${go}/bin/go build -o $GITROOT/$(basename $GITROOT) $GITROOT/main.go
            mkdir -p ~/.terraform.d/plugins/hashicorp.com/edu/hashicups/0.2/${OS_LINUX_ARCH}
            mv $GITROOT/terraform-provider-hashicups ~/.terraform.d/plugins/hashicorp.com/edu/hashicups/0.2/${OS_LINUX_ARCH}
          '';

          run-package = pkgs.writeShellScriptBin "run" ''
            GITROOT=$(git rev-parse --show-toplevel)
            ${go}/bin/go run "$@".go
          '';

          run-main = pkgs.writeShellScriptBin "run-main" ''
            GITROOT=$(git rev-parse --show-toplevel)
            ${go}/bin/go run $GITROOT/main.go
          '';

          go-format = pkgs.writeShellScriptBin "go-format" ''
            GITROOT=$(git rev-parse --show-toplevel)
            ${go}/bin/go fmt ./...
          '';
          signin = pkgs.writeShellScriptBin "signin" ''
            ${pkgs.curl}/bin/curl -X POST localhost:19090/signin -d '{"username": "education", "password": "test123" }'
          '';

      });
      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.build-all
              self.packages.${system}.run-package
              self.packages.${system}.run-main
              self.packages.${system}.go-format
              self.packages.${system}.signin
            ];
            buildInputs = with pkgs; [
                go
                gopls
                gotools
                go-tools
                terraform
              ];
            shellHook = "export PS1='[$PWD]\n❄ '";
            HASHICUPS_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NzMxMzQxMTYsInVzZXJfaWQiOjEsInVzZXJuYW1lIjoiZWR1Y2F0aW9uIn0.fgWp9SobZ0Oz_oBINFnKp22nQ1OHVF222MPJwioqgNI";
            OS_ARCH="${OS_LINUX_ARCH}";
          };
        });
    };
}
