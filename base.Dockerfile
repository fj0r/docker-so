ENV DEBUGE=
ENV PREBOOT=
ENV POSTBOOT=
ENV CRONFILE=
COPY entrypoint /entrypoint

ENV git_pull=
#ENV ed25519_xxx=

ENTRYPOINT [ "/entrypoint/init.sh" ]
