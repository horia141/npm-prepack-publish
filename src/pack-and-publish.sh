#!/bin/bash

ERR_NO_NPM_TOKEN=1
ERR_INVALID_F=2
ERR_INVALID_E=3

if [[ -z ${NPM_TOKEN} ]]
then
    echo 'Need the NPM_TOKEN env variale'
    exit ${ERR_NO_NPM_TOKEN}
fi

# Skip standard `npm pack` and do the archiving ourselves. Include only the bare minimum and use a flater directory structure so imports will be easy.

PACKAGE_NAME=$($(npm bin)/json -f package.json name | sed 's/[@",]//g' | sed 's|[/]|-|g' | sed 's/ //g')
PACKAGE_VERSION=$($(npm bin)/json -f package.json version | sed 's/[", ]//g')
PACKAGE="$PACKAGE_NAME-$PACKAGE_VERSION.tgz"

SAW_README=0
SAW_PACKAGE=0

WORK_DIR=work.${RANDOM}

rm -rf ${WORK_DIR}
mkdir ${WORK_DIR}
for f in $($(npm bin)/json -f package.json filesPack | $(npm bin)/json -ka)
do
    ACTION_DEST=$($(npm bin)/json -f package.json filesPack[\"${f}\"])
    ACTION=${ACTION_DEST:0:2}
    DEST=${ACTION_DEST:2}
    if [[ ${ACTION} = f: ]]
    then
        if ! [[ -f ${f} ]]
        then
           echo 'Source with f: is not actually a file'
           exit ${ERR_INVALID_F}
        fi

        if [[ ${f} = "README.md" ]]
        then
            SAW_README=1
        fi

        if [[ ${f} = "package.json" ]]
        then
            SAW_PACKAGE=1
        fi

        mkdir -p ${WORK_DIR}/$(dirname ${DEST})
        cp ${f} ${WORK_DIR}/$(dirname ${DEST})
    elif [[ ${ACTION} = c: ]]
    then
        mkdir -p ${WORK_DIR}/$(dirname ${DEST})
        cp -r ${f} ${WORK_DIR}/$(dirname ${DEST})
    elif [[ ${ACTION} = e: ]]
    then
        if ! [[ -d ${f} ]]
        then
            echo 'Source with e: is not actually a directory'
            exit ${ERR_INVALID_E}
        fi

        mkdir -p ${WORK_DIR}/${DEST}
        cp -r ${f}/* ${WORK_DIR}/${DEST}
    fi
done

if [[ ${SAW_README} = 0 ]]
then
    cp README.md ${WORK_DIR}
fi

if [[ ${SAW_PACKAGE} = 0 ]]
then
    cp package.json ${WORK_DIR}
fi

cd ${WORK_DIR}

../node_modules/.bin/json -q -I -f package.json -e "this.files = []"
for f in `ls`
do
    ../node_modules/.bin/json -q -I -f package.json -e "this.files.push(\"${f}\")"
done

npm pack
../node_modules/.bin/ci-publish

EXIT_CODE=$?

cd ..
rm -rf ${WORK_DIR}

exit ${EXIT_CODE}
