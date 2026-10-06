# Pinned toolchain for Ueber's verification of YAS.
#
#   docker build -t yas .
#   docker run --rm yas
#
# SWI_VERSION defaults to the swipl image tagged "stable" at the time of
# pinning; CI also builds with other versions (see .github/workflows/ci.yml).
ARG SWI_VERSION=10.0.2
FROM swipl:${SWI_VERSION}

WORKDIR /yas
COPY . /yas

CMD ["bash", ".github/ci/ueber-verify.sh"]
