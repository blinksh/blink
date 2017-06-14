#!/bin/sh
set -e

INSTALL_MAN1_DIR=${INSTALL_ROOT}${GZIP_PREFIX}/share/man/man1

install -d -m 0755 "${INSTALL_MAN1_DIR}"
for script in ${GZIP_SCRIPTS}; do
	printf "Installing ${script} ...\n"
	install -m 0755 ${SRCROOT}/gzip/${script} ${INSTALL_DIR}/${script}
	install -m 0644 ${SRCROOT}/gzip/${script}.1 ${INSTALL_MAN1_DIR}/${script}.1
done

set ${GZIP_LINKS}
while [ $# -ge 2 ]; do
	l=$1
	shift
	t=$1
	shift
	printf "Creating link: ${t} -> ${l} ...\n"
	ln -f ${INSTALL_DIR}/${l} ${INSTALL_DIR}/${t}
	ln -f ${INSTALL_MAN1_DIR}/${l}.1 ${INSTALL_MAN1_DIR}/${t}.1
done
