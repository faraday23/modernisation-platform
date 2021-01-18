#!/bin/bash

run_terraform () {
  echo "Running terraform init for $called_function"
  output=$(terraform init -input=false 2>&1) || (echo "$output" && false)
  echo "Running terraform workspace select default for $called_function"
  output=$(terraform workspace select default) || (echo "$output" && false)
}

get_all_local_application_definitions () {
  jq -r '(input_filename | ltrimstr("environments/") | rtrimstr(".json"))' environments/*.json > tmp/local-applications.tmp
}

get_all_local_environment_definitions_split_by_application () {
  for file in environments/*.json
  do
    filename=$(basename "$file" .json)
    jq -r '(input_filename | ltrimstr("environments/") | rtrimstr(".json")) + "-" + .environments[]' $file > tmp/"$filename"-local.tmp
  done
}

create_local_workspaces () {
  cd terraform/environments || exit
  while read -r line; do
    called_function="create_local_workspaces for application $line"
    mkdir -p "$line"
    cp ../templates/backend.tf "$line"/backend.tf
    cp ../templates/secrets.tf "$line"/secrets.tf

    if  [[ ! -z `cat $file | jq '.bastion[]?'` ]]; then
            cp ../templates/bastion.tf "$line"/bastion.tf
    fi
      
    sed -i '' -e "s/application_name/$line/g" "$line"/backend.tf
    cd "$line" || exit
    run_terraform
    terraform workspace list > ../../../tmp/"$line"-remote.tmp
    cd ..
    cat ../../tmp/"$line"-remote.tmp | grep "\S" | grep -v "default" | tr -d "* " | tee ../../tmp/"$line"-remote.tmp
  done < ../../tmp/local-applications.tmp
  cd ../..
}

compare_local_and_remote_definitions () {
  for file in tmp/*; do
    sort "$file" -o "$file"
  done
  while read -r line; do
    if [ -s tmp/"$line"-remote.tmp ]; then
      grep -xvFf tmp/"$line"-remote.tmp tmp/"$line"-local.tmp > tmp/"$line"-remote-missing.tmp
    else
      cp tmp/"$line"-local.tmp tmp/"$line"-remote-missing.tmp
    fi
  done < tmp/local-applications.tmp
  echo "Finished comparing local and remote definitions"
}

create_remote_workspaces () {
  while read -r line; do
    while read -r workspace; do
      called_function="create_remote_workspaces: creating $workspace in $line"
      cd "terraform/environments/$line" || exit
      run_terraform
      echo "Running terraform workspace new $workspace"
      output=$(terraform workspace new "$workspace") || (echo "$output" && false)
      cd ../../..
    done < tmp/"$line-remote-missing.tmp"
  done < tmp/local-applications.tmp
}

main () {
  mkdir -p tmp/
  get_all_local_application_definitions &&
  get_all_local_environment_definitions_split_by_application &&
  create_local_workspaces &&
  compare_local_and_remote_definitions &&
  create_remote_workspaces &&
  rm -r tmp/
}

main
