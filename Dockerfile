# Pinned toolchain for Ueber's verification of YAS.
#
#   docker build -t yas .
#   docker run --rm yas
#
# SWI_VERSION defaults to the swipl image tagged "stable" at the time of
# pinning; CI also builds with other versions (see .github/workflows/ci.yml).
# SWI_DIGEST pins the exact image: official images are rebuilt under the same
# tag from time to time. Look it up with
#   docker buildx imagetools inspect swipl:VERSION
# (the Digest of the manifest list) and pass both arguments together.
ARG SWI_VERSION=10.0.2
ARG SWI_DIGEST=sha256:2723fefd35116f92f68da22a487b1b01b584ac0b4b81fcd971c7ab2222f5d3e7
FROM swipl:${SWI_VERSION}@${SWI_DIGEST}

WORKDIR /yas
COPY . /yas

CMD ["bash", ".github/ci/ueber-verify.sh"]
