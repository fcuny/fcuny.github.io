FROM klakegg/hugo:0.83.1-ext-alpine-onbuild AS hugo

FROM pierrezemb/gostatic

COPY --from=hugo /target /srv/http/

CMD ["-port", "8080" , "-https-promote"]
