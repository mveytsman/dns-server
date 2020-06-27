with (import <nixpkgs> { });
mkShell {
  name = "mc-hammer";
  buildInputs = [elixir_1_10 dnsutils];
  shellHook = ''
    mkdir -p .nix-mix
    mkdir -p .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-hex
    export PATH=$MIX_HOME/bin:$PATH
    export PATH=$HEX_HOME/bin:$PATH
    export ERL_AFLAGS="-kernel shell_history enabled"
  '';
}