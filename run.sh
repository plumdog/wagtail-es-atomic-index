#!/bin/bash -ex

# Apply a directory of patches to the bakerydemo codebase
function apply_patches() {
    source_dir="$1"
    target_dir="$2"

    while IFS= read -r patchpath; do
        echo $patchpath
        source_patch="$source_dir/$patchpath";
        target_file="$target_dir/$(echo $patchpath | sed 's/\.patch$//')"

        patch "$target_file" "$source_patch"
    done <<< "$(cd "$1" && find . -name '*.patch')"
}

function main() {
    patchset="$1"

    if [[ -n "$patchset" ]] && [[ ! -d "patches/tests/$patchset" ]]; then
        >&2 echo "No such patchset $patchset"
        exit 1
    fi

    # Blat and recreate the bakerydemo source code
    if [[ ! -f master.zip ]]; then
        wget https://github.com/wagtail/bakerydemo/archive/master.zip -O master.zip
    fi
    rm -rf bakerydemo
    mkdir unzip_temp
    unzip -q master.zip -d unzip_temp
    mv unzip_temp/bakerydemo-master/ bakerydemo
    rm -rf unzip_temp

    # Apply the patches that we always want
    apply_patches "patches/shared/" "bakerydemo/"

    # Apply the patches for the selected test
    if [[ -n "$patchset" ]]; then
        apply_patches "patches/tests/$patchset" "bakerydemo/"
    fi

    (cd bakerydemo && {
         # Stand up bakerydemo
         docker-compose down -v || echo "Nothing to tear down"
         docker-compose up --build -d
         # Wait for the migrations to complete
         while docker-compose run --rm app /venv/bin/python manage.py showmigrations | grep '\[ \]' >> /dev/null; do
             sleep 2
         done
         sleep 1
         docker-compose run --rm app /venv/bin/python manage.py load_initial_data

         # Run update_index
         docker-compose run --rm app /venv/bin/python manage.py update_index

         # Check for bug https://github.com/elastic/elasticsearch/issues/24644
         set +x
         echo "#####################"
         echo "Happy behaviour is to see a 404, unhappy behaviour is to see a 200"
         echo "###"
         docker_output="$(docker-compose run --rm app bash -ex -c 'sleep 10 && index_name=$(curl http://elasticsearch:9200/_cat/indices?format=json | jq -r .[0].index) && echo $index_name && curl -I -XHEAD "http://elasticsearch:9200/$index_name/_alias/doesnotexist?format=json"')"
         if echo "$docker_output" | grep 'HTTP/1.1 404 Not Found'; then
             echo "[Good] - Happy behaviour observed"
         else
             echo "[Bad] - Unhappy behaviour observed"
         fi
         echo "#####################"

         sleep 2

         # Check if search seems to be working in Wagtail
         if curl --silent http://localhost:8000/search/?q=bread | grep 'Bread and Circuses'; then
             if !(curl --silent http://localhost:8000/search/?q=notbread | grep 'Bread and Circuses'); then
                 echo "[Good] - Search appears to be working"
             else
                 echo "[Bad] - Search appears to be failing, found result that should not appear"
             fi
         else
             echo "[Bad] - Search appears to be failing, did not find result that should appear"
         fi
         echo "#####################"
     })
}

main $@
