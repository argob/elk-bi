FROM logstash
COPY conf.d $LS_SETTINGS_DIR/conf.d
COPY mysql-connector-java-5.1.6.jar $LS_SETTINGS_DIR/
COPY entrypoint.sh /
ENTRYPOINT ["bash", "/entrypoint.sh"]
