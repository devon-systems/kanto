_: {
  flake.nixosModules.vermilion = {pkgs, ...}: {
    services.ollama = {
      package = pkgs.ollama-vulkan;
      environmentVariables = {
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_NUM_PARALLEL = "2";
        OLLAMA_MAX_QUEUE = "8";
        OLLAMA_CONTEXT_LENGTH = "65536";
      };
    };
  };
}
