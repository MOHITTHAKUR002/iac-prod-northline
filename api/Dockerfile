FROM node:20-alpine

RUN addgroup -g 1000 app && adduser -u 1000 -G app -D app \
  && apk add --no-cache curl

WORKDIR /app

COPY server.js healthcheck.sh ./
RUN chmod +x healthcheck.sh && chown -R app:app /app

USER 1000:1000

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/app/healthcheck.sh"]

CMD ["node", "server.js"]
