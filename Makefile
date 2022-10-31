COUNTRY=AU
STATE=Queensland
LOCATION=Gladstone
ORG=Beer4Peer
CN=$(ORG) Root Certificate
CERTSUBJ='/CN=$(CN)/C=$(COUNTRY)/ST=$(STATE)/O=$(ORG)'
ICERTSUBJ='/CN=$(ORG) Intermediate 2022-2024/C=$(COUNTRY)/ST=$(STATE)/O=$(ORG)'
CADAYS=7200

CADIR=$(shell pwd)/ca
CADIRS=$(addprefix $(CADIR)/,certs crl csr newcerts private)
IDIR=$(CADIR)/intermediate
IDIRS=$(addsuffix /,$(addprefix $(IDIR)/,certs crl csr newcerts private))
CLIENTDIR=$(shell pwd)/client
CLIENTDIRS=$(addsuffix /,$(addprefix $(CLIENTDIR)/,certs crl csr newcerts private))

PRIVKEYS=$(addsuffix /private/private_key.pem,$(CADIR) $(IDIR))

WEBROOT=/usr/local/b4p/public

.PHONY: client
client: $(CLIENTDIR)/ $(CLIENTDIRS)


.PHONY: ca
ca: $(CADIR)/ca.cert.pem $(WEBROOT)/root.pem
	@echo privkey ok

$(WEBROOT):
	mkdir -p $(WEBROOT)

$(WEBROOT)/root.pem: $(CADIR)/ca.cert.pem | $(WEBROOT)
	cp $< $@


.PHONY: intermediate i
i intermediate: ca $(IDIR)/certs/ca-chain.cert.pem  | $(IDIR)/ $(IDIRS) $(IDIR)/serial $(IDIR)/crlnumber
	@echo i ok
	openssl x509 -noout -text -in $(IDIR)/certs/intermediate.cert.pem

.PHONY: clean
clean:
	rm -rf $(CADIR)

ALLDIRS=$(CADIR)/ $(IDIR)/ $(IDIRS)/ $(CADIRS)/ $(CLIENTDIR)/ $(CLIENTDIRS)
$(ALLDIRS):
	mkdir $@

$(CADIR)/index.txt: | $(CADIR)/
	touch $@

$(IDIR)/index.txt: | $(IDIR)/
	touch $@

$(CADIR)/serial $(IDIR)/serial:
	echo 12 > $@

$(IDIR)/crlnumber:
	echo 7 > $@

$(PRIVKEYS): | $(CADIR)/index.txt $(CADIR)/serial $(IDIR)/index.txt $(IDIR)/serial $(CADIRS)/ $(IDIRS)/
	openssl ecparam -noout -name prime256v1 -genkey -out $(@) -outform PEM

$(CADIR)/ca.cert.pem: $(CADIR)/private/private_key.pem $(CADIR)/openssl.conf
	openssl req -x509 -new -nodes -key $(CADIR)/private/private_key.pem -keyform PEM -days $(CADAYS) -out $@ -subj $(CERTSUBJ) -config $(CADIR)/openssl.conf -sha256 -extensions v3_ca

.PHONY: openssl
openssl: $(CADIR)/openssl.conf

$(CADIR)/openssl.conf: openssl.conf.base
	sed -e 's!__CADIR__!$(CADIR)!' -e 's!__IDIR__!$(IDIR)!'< $< > $@

$(IDIR)/csr/intermediate.csr.pem: $(CADIR)/openssl.conf $(IDIR)/private/private_key.pem
	openssl req -config $(CADIR)/openssl.conf -new -nodes -sha256 -key $(IDIR)/private/private_key.pem -out $@ -subj $(ICERTSUBJ)

$(IDIR)/certs/intermediate.cert.pem: $(IDIR)/csr/intermediate.csr.pem | $(CADIR)/openssl.conf
	openssl ca -config $(CADIR)/openssl.conf -extensions v3_intermediate_ca -days 720 -notext -in $(IDIR)/csr/intermediate.csr.pem -out $@ -rand_serial -batch

$(IDIR)/certs/ca-chain.cert.pem: $(IDIR)/certs/intermediate.cert.pem
	cat $< $(CADIR)/ca.cert.pem > $@


