{pkgs}: let
  image = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/peonist-ai/halogen-flash-server";
    imageDigest = "sha256:273714ccb64dabb7fac0418ee1b6dd83eb57d2fd44cf286eb68a7c694a27c203";
    hash = "sha256-W2SqAYENtFsaRnfhG9EBcOhmkec5R8VBgyyJbcRClsQ=";
    finalImageTag = "0.18.22";
  };
  # Nix builders cannot create setuid files. Halogen runs unprivileged and
  # does not use the image's account-management helpers.
  unpacker = pkgs.umoci.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace pkg/unpriv/unpriv.go \
          --replace-fail 'os.Chmod(path, mode)' 'os.Chmod(path, mode &^ (os.ModeSetuid | os.ModeSetgid))'
      '';
  });
  rootfs =
    pkgs.runCommand "halogen-rootfs-0.18.22" {
      nativeBuildInputs = [pkgs.skopeo unpacker pkgs.jq];
    } ''
      skopeo --insecure-policy copy docker-archive:${image} oci:oci:halogen
      umoci unpack --rootless --image oci:halogen bundle
      mkdir -p "$out"
      mv bundle/rootfs "$out/rootfs"
      manifest=$(jq -r '.manifests[0].digest | split(":")[1]' oci/index.json)
      config=$(jq -r '.config.digest | split(":")[1]' "oci/blobs/sha256/$manifest")
      jq '.config' "oci/blobs/sha256/$config" > "$out/image-config.json"
    '';
  entrypoint = pkgs.runCommand "halogen-loopback-entrypoint" {} ''
    cp ${rootfs}/rootfs/usr/local/bin/entrypoint.sh "$out"
    chmod u+w "$out"
    substituteInPlace "$out" --replace-fail '--host 0.0.0.0' '--host 127.0.0.1'
  '';
  revision = "195697374b375f2133b2a61dc113e37b4b905ac6";
  fetchAsset = name: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/peonist-ai/halogen-qwen3.8-flash-next/resolve/${revision}/${name}";
      inherit hash;
    };
  tokenizer = pkgs.linkFarm "halogen-tokenizer" (pkgs.lib.mapAttrsToList (name: hash: {
    inherit name;
    path = fetchAsset "tokenizer/${name}" hash;
  }) (builtins.fromJSON (builtins.readFile ./_tokenizer-hashes.json)));
  mtp = fetchAsset "qwen38-flash-next-mtp.hgn" "sha256-D1DpYm35gWjnxuDMJk4qkrUYTdiFoXWgZijZebXtzus=";
  vision = fetchAsset "qwen38-flash-next-vision.hgn" "sha256-1i4K5VP+iK/Tgzcz1KTGafNNIP2N/OS5YQUlvtITSxA=";
in {
  inherit rootfs entrypoint tokenizer mtp vision;
}
