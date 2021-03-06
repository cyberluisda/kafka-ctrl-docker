#!/bin/bash
set -e

# Common configuration
ZOOKEEPER_ENTRY_POINT="${ZOOKEEPER_ENTRY_POINT:-zookeeper:2181}"
KAFKA_BROKER_LIST="${KAFKA_BROKER_LIST:-kafka:9092}"
# Only for get listed here.
WAIT_FOR_SERVICE_UP="${WAIT_FOR_SERVICE_UP}"
WAIT_FOR_SERVICE_UP_TIMEOUT="${WAIT_FOR_SERVICE_UP_TIMEOUT:-10s}"
WAIT_FOR_TOPICS_TIMEOUT="${WAIT_FOR_TOPICS_TIMEOUT:-10}"

usage() {
  cat <<EOF
kafka-ctl COMMAND [options]

 Were COMMAND is one of:
  list-brokers: List brokers handled by zookeeper
    options: [ --format | -n ]
      --format: Pretty print output json
      -n: count the number of brokers instead of list it
  list-topics : list all topics
  wait-for-topics: Wait for topics exist, or timeout.
    options: [ --timeout SECONDS] NAME0 ... NAMEn
      SECONDS: Number of seconds to wait after exist with tiemout error
      NAMEx: Topics that should exists (all) until exit.
  delete-topic : delete a on more topic
    options : NAME0 ... NAMEn
      NAMEx : the name of topic to remove
  describe-topic : give info of one or more topics
    options : NAME0 ... NAMEn
      NAMEx : the name of topic
  create-topic : create one or more topics
    options : [--min-num-brokers-up NUM_BROKERS] [-s|-ns] [-r REPLICATION_FACTOR0 ] [-p PARTITIONS0] [-b BROKER_IDS0] [-nb] [-bs] [-nbs] [-nc] [-c CONFIG0_1 ... -c CONFIG0_n] NAME0 ... [-s] [-r REPLICATION_FACTORn ] [-p PARTITIONSn] [-b BROKER_IDSn] [-nb] [-bs] [-nbs] [-nc] [-c CONFIGn_1 ... -c CONFIGn_n] NAMEn
      --min-num-brokers-up. If present create topics will be launched only if
        number of kafka brokers is greather or equal that NUM_BROKERS.
        See list-brokers -n for more information
      NAMEx : the name of the topic to create
      -s : If active (present) only create topic if not exists (-ns inverse)
      REPLICATION_FACTORx : replication factor used. Default 1
      PARTITIONSx : number of partitions. Default 1
      BROKER_IDSx : Select this borkers ids to create topic only (CSV format
        1001,1002,1007). All main partitions and replicas will be assigned to
        kafka servers which broker id is in this lits in circular order.
        Note that this options is passed to next topic description, if you set
        for first topic and you want deactivate in next topics, you must set -nb
        option. For example
          create-topic -p 15 -b 0,1 topic1 -r 2 -nb topic2

      -bs | -nbs. Flag (-bs activeted -nbs deactivated) that force to check each broker is up in the cluster at execution moment.
        By default is deactivate.
        
      -nb Clean previous -b option.

      -c Override default configuration values for all topics (See kafka-config.sh for more information).
         Values are set for current topic and next. If you need reset overrided configuration values use -nc

         For example create-topic -c prop1=value1 prop2=value2 topic1 -c prop3=value3 topic2
         is the same like:
         create-topic -c prop1=value1 prop2=value2 topic1 -nc -c prop1=value1 prop2=value2 prop3=value3 topic2

         In both cases prop1=value1 and prop2=value2 is applied when create topic1 and topic2, but prop3=value3 is
         applied only when create topic2

         In next case reate-topic -c prop1=value1 prop2=value2 topic1 -c prop3=value3 topic2 -nc topic3
         topic3 has not any configuration value override from default (defined at kafka server level)

      -nc Remove all CONIFx_x defined to this time

      REPLICATION_FACTOR and PARTITIONS are remembered if you set they apply to next topics until you set it
      Example create-topic -s -r 1 -p 2 topic1 topic2 is the same like
      create-topic -s -r 1 -p 2 topic1 -s -r 1 -p 2 topic2
  consume : consume and show data from a topic
    options : NAME [--no-from-beginning] [--property PROP1=VALUE1 ... --property PROPn=VALUEn]
      NAME : name of the topic to consume data
      --no-from-beginning : if it is no present (default) data will
        be consumed from the beginning of the topic. only new data in
        other case
      --property PROPx=VALUEx : set property PROPx with value VALUEx in consumer
  produce : produce data (readed from file or stdin) and put in a topic
    options : NAME [--file|-f filepath] [--property PROP1=VALUE1 ... --property PROPn=VALUEn]
      NAME : name of the topic to consume data
      --file|-f filepath file to use as data input, if it is not defined data will be read from stdin
      --property PROPx=VALUEx : set property PROPx with value VALUEx in producer

  repartition : reallocate partitions into diferents nodes for a topic
    options :
        --all-topics|(NAME0 NAME1 ... NAMEn [--])
        [--dest-broker-list|-b BROKER_ID1,BROKER_ID2, ... ,BROKER_IDn]
        [--dry-run]
        [--format-plan]
        [--verify [--wait-finished TIMEOUT]]

      --all-topics: Look-up and apply to all topics in cluster. BE CAREFULLY
      NAMEx : name of the topic to reallocate partitions
      -- Mandatory if any of the next options is defined when topis are defined by name
      --dest-broker-list BROKER_IDx. List of brokers to use as destination. By default
        all brokers in cluster (see list-brokers command) are set.
        Note that list of broker ids must be only one string without spaces
        separates by comma. (CSV)
      --dry-run. If present only information about planning is showed. Any action is
        persisted.
      --verify. If present verify procedure will be launched.
      --wait-finished. If it is present (with --verify) wait for all partitios
        will be reallocated or TIMEOUT (in secs) is reached.
      --format-plan. If present and plan must be applied json data will formatted
        with "jd" command.

  repartition-with-plan: reallocate partitions based on json with plan.
    This option can be used to implement a plan showed when lauch repartition with
    --dru-run option.

    In same way, this option cabe used  to roll-back previous repartition too
    based on information showed from repartition command or for output of
    previous execution of this command.

    options: JSON_WITH_PLAN
    JSON_WITH_PLAN : Plan launched (one output of repartition command) in json
      format

  verify-repartition : Verify a repartition plan previously executed.
    options: JSON_WITH_PLAN
      JSON_WITH_PLAN : Plan launched (one output of repartition command) in json
        format

  ENVIRONMENT CONFIGURATION.
    There are some configuration and behaviours that can be set using next Environment
    Variables:

      ZOOKEEPER_ENTRY_POINT. Define zookeeper entry point. By default: zookeeper:2181

      KAFKA_BROKER_LIST. Define kafka bootstrap server entry points. By default:
        kafka:9092

      WAIT_FOR_SERVICE_UP. If it is defined we wait (using dockerize) for service(s)
        to be started before to perform any operation. Example values:

        WAIT_FOR_SERVICE_UP="tcp://kafka:9092" wait for tcp connection to kafka:9092
        are available

        WAIT_FOR_SERVICE_UP="tcp://kafka:9092 tcp://zookeeper:2181" Wait for
        kafka:9092 and zookeeper:2818 connections are avilable.

        If one of this can not be process will exit with error will be. See
        https://github.com/jwilder/dockerize for more information.

      WAIT_FOR_SERVICE_UP_TIMEOUT. Set timeot when check services listed on
        WAIT_FOR_SERVICE_UP. Default value 10s

      KEEP_ALIVE_SLEEP_TIME. If defined and value is an integer greather than 0,
        command do not exit and enter in a "sleep-loop" which each sleep command
        has this value as argument.

        Usefull if you are using this command in orchestrated (like
        docker-compose) docker container and need other dockers wait for one
        functionallity (like create-topics).

EOF

}

list_brokers() {
  local jqPattern=""
  if [ "$1" == "-n" ]; then
    jqPattern=". | length"
  elif [ "$1" == "--format" ]; then
    jqPattern="."
  fi

  local brokers=$(zookeeper-shell.sh "${ZOOKEEPER_ENTRY_POINT}" <<< "ls /brokers/ids" | tail -1)

  if [ -z "$jqPattern" ]; then
    echo $brokers
  else
    echo "$brokers" | jq "$jqPattern"
  fi
}

list_topics() {
  kafka-topics.sh --list --zookeeper "${ZOOKEEPER_ENTRY_POINT}"
}

wait_for_topics(){
  local timeout=${WAIT_FOR_TOPICS_TIMEOUT}
  if [ "$1" == "--timeout" ]; then
    if [ -z "$2" ]; then
      echo "Error. --timeout option without value in wait for topics function"
      usage
      exit 1
    fi
    local timeout=$2
    shift 2
  fi
  echo "Waiting for topics $@ (timeout $timeout)"
  local iteration=0
  while [ $iteration -lt $timeout ]; do
    echo -n "."
    local topics=$(list_topics | awk '{print $1}')
    local found=0
    for topic in $@; do
      if echo "$topics" | fgrep "$topic" 2>&1 > /dev/null; then
        found=$((found + 1))
      fi
    done

    if [ $found -eq $# ]; then
      echo "Topics $@ found"
      exit 0
    fi
    iteration=$((iteration + 1))
    sleep 1
  done

  echo "Any topic of $@ did not find. Timeout of $timeout seconds reached".
  exit 1
}

delete_topics() {
  local name=""
  while [ -n "$1" ]
  do
    name="$1"
    kafka-topics.sh --delete --topic "$name" --zookeeper "${ZOOKEEPER_ENTRY_POINT}"
    shift
  done
}

describe_topic() {
  local name=""
  while [ -n "$1" ]
  do
    name="$1"
    kafka-topics.sh --describe --topic "$name" --zookeeper "${ZOOKEEPER_ENTRY_POINT}"
    shift
  done
}

create_topics() {
  # Checks for min number of kafka brokers if enabled
  if [ "$1" == "--min-num-brokers-up" ]; then
    if [ -z "$2" ]; then
      echo "create-topic with --min-num-brokers-up option without value"
      usage
      exit 1
    fi

    local desired="$2"
    local existingBrokers=$(list_brokers -n)
    if [ "$existingBrokers" -lt "$desired" ]; then
      echo "ERROR: create-topic with --min-num-brokers-up (kafka brokers) set to $desired, but only $existingBrokers brokers detected on zookeeper."
      exit 1
    fi
    shift 2
  fi

  local safe="no"
  local repl_fct=1
  local partitions=1
  local name=""
  local configs=""
  local only_in_brokers=""
  local safe_brokers="no"
  while [ -n "$1" ]
  do
    case $1 in
      -r)
        shift 1
        repl_fct=$1
        ;;
      -p)
        shift 1
        partitions=$1
        ;;
      -b)
        shift 1
        only_in_brokers="$1"
        ;;
      -bs)
        safe_brokers="yes"
        ;;
      -nbs)
        safe_brokers="no"
        ;;
      -nb)
        only_in_brokers=""
        ;;
      -c)
        shift 1
        configs="$configs --config $1"
        ;;
      -nc)
        configs=""
        ;;
      -s)
        safe="yes"
        ;;
      -ns)
        safe="no"
        ;;
      *)
        name="$1"
        if [ -z "$only_in_brokers" ]
        then
          _create_topic_all_brokers "$safe" "$name" "$partitions" "$repl_fct" "$configs"
        else
          _create_topic_brokers_assigned "$safe" "$name" "$only_in_brokers" "$safe_brokers" "$partitions" "$repl_fct" "$configs"
        fi
        ;;
    esac
    shift
  done
}

# Help function to simplify create_topic generic
##
# $1 safe mode?. Yes or no
# $2 topic name
# $3 partitions
# $4 replication factor
# $5 configs. Expected format is all in one string. Example '--config a=b --config c=j'
_create_topic_all_brokers(){
  local safe="$1"
  local name="$2"
  local partitions="$3"
  local repl_fct="$4"
  local configs="$5"
  if [ "$safe" == "yes" ]
  then
    if kafka-topics.sh --describe --topic "$name" --zookeeper "${ZOOKEEPER_ENTRY_POINT}" 2>&1 | fgrep "$name" > /dev/null
    then
      echo "Topic $name exists. Ignoring"
    else
      kafka-topics.sh --create --topic "$name" --replication-factor "$repl_fct" --partitions "${partitions}" $configs --zookeeper "${ZOOKEEPER_ENTRY_POINT}"
    fi
  else
    kafka-topics.sh --create --topic "$name" --replication-factor "$repl_fct" --partitions "${partitions}" $configs --zookeeper "${ZOOKEEPER_ENTRY_POINT}"
  fi
}

# Help function to simplify create_topic when kafka brokers are restricted
##
# $1 safe mode?. Yes or no
# $2 topic name
# $3 broker list
# $4 safe broker list?. If yes check that brokers assigned exist now.
# $5 partitions
# $6 replication factor
# $7 configs. Expected format is all in one string. Example '--config a=b --config c=j'
_create_topic_brokers_assigned(){

  local safe=$1
  local name="$2"
  local brokers="$3"
  local safe_brokers="$4"
  local partitions="$5"
  local repl_fct="$6"
  local configs="$7"

  if [ $(_length_csv $brokers) -lt $repl_fct ]
  then
    echo "ERROR number of replicas $repl_fct must be less or equal than number of brokers $(length_csv $brokers). Topic $name will not be created"
  else
    # available broker list
    local available_broker_list=""
    if [ "$safe_brokers" == "yes" ]
    then
      available_broker_list=$(list_brokers)
    fi
    # Resolve replica assignement
    local partitions_assigned=""
    for ((i=0;i<$partitions;i++))
    do
      local new_broker="$(_circular_csv $brokers $i)"
      # Check for available broker
      if [ "$safe_brokers" == "yes" ]
      then
        if echo "$available_broker_list" | egrep -Ee "(\\[|[, ])${new_broker}(\\]|[ ,])" 2>&1 >/dev/null
        then
          echo -n
        else
          echo "WARNING broker $new_broker is not available now (when assing primary partition), topic $name will not be created"
          return
        fi
      fi

      # First iteration => no separator
      if [ $i == 0 ]
      then
        partitions_assigned="$new_broker"
      else
        partitions_assigned="$partitions_assigned,$new_broker"
      fi

      # Replicas
      for ((j=1;j<$repl_fct;j++))
      do
        local new_replica_broker="$(_circular_csv $brokers $((i+j)))"
        # Check for available broker
        if [ "$safe_brokers" == "yes" ]
        then
          if echo "$available_broker_list" | egrep -Ee "(\\[|[, ])${new_replica_broker}(\\]|[ ,])" 2>&1 >/dev/null
          then
            echo -n
          else
            echo "WARNING broker $new_replica_broker is not available now (when assing partition replica), topic $name will not be created"
            return
          fi
        fi
        partitions_assigned="$partitions_assigned:$new_replica_broker"
      done
    done

    if [ "$safe" == "yes" ]
    then
      if kafka-topics.sh --describe --topic "$name" --zookeeper "${ZOOKEEPER_ENTRY_POINT}" 2>&1 | fgrep "$name" > /dev/null
      then
        echo "Topic $name exists. Ignoring"
      else
        kafka-topics.sh --create --topic "$name" --replica-assignment "$partitions_assigned" $configs --zookeeper "${ZOOKEEPER_ENTRY_POINT}"
      fi
    else
      kafka-topics.sh --create --topic "$name" --replica-assignment "$partitions_assigned" $configs --zookeeper "${ZOOKEEPER_ENTRY_POINT}"
    fi
  fi
}

# Return element like a circular array from CSV string.
# Based on resolve module of index
##
# $1 string that will be split into array
# $2 offset
# $3 Optional separator to split array by default ','
_circular_csv() {
  local separator=","
  if [ -n "$3" ]
  then
    separator="$3"
  fi
  IFS="$separator" read -r -a target <<< "$1"
  local length=${#target[*]}
  local offset=$2
  local idx=$((offset % length))

  # Return item
  echo -n ${target[idx]}
}

# Return number of items from CSV string.
##
# $1 string that will be split into array
# $2 Optional separator to split array by default ','
_length_csv(){
  local separator=","
  if [ -n "$2" ]
  then
    separator="$2"
  fi
  IFS="$separator" read -r -a target <<< "$1"

  echo -n ${#target[@]}
}
consume() {
  local from_beginning="--from-beginning"
  local name="$1"
  shift
  local otherOptions=()
  while [ ! -z "$1" ]
  do
    case $1 in
      --no-from-beginning)
        from_beginning=""
        ;;
      *)
        otherOptions+=" $1"
        ;;
    esac
    shift
  done

  kafka-console-consumer.sh ${otherOptions[@]} --topic "$name" "$from_beginning" --bootstrap-server "${KAFKA_BROKER_LIST}"
}

produce() {
  local name="$1"
  shift
  ## Empty file is standar input
  local inputFile=""
  case "$1" in
    --file|-f)
        if [ -z "$2" ]
        then
          echo "produce with --file|-f option without value"
          usage
          exit 1
        fi
        inputFile="$2"
        shift 2
      ;;
  esac
  cat $inputFile | kafka-console-producer.sh $@ --topic "$name" --broker-list "${KAFKA_BROKER_LIST}"
}

repartition(){

  # topics name
  local topics=""
  if [ "--all-topics" == "$1" ]
  then
    # Lookup for al topics
    topics="$(list_topics | tr '\n' ' ')"
    shift 1
  else
    # GEt topics from parameters
    while [ -n "$1" ]
    do
      # pass "--"
      if [ "$1" == "--" ]
      then
        shift
        break
      fi
      topics="$topics $1"
      shift 1
    done
  fi

  if [ -z "$topics" ]
  then
    echo "ERROR: repartition without any topic"
    usage
    exit 1
  fi

  # broker_ids, dry-run, verify and formatPlan
  local brokerList=""
  local dryRun="no"
  local verify="no"
  local formatPlan="no"
  local waitFinishedTimeout=""
  while [ -n "$1" ]
  do
    case "$1" in
      --dest-broker-list|-b)
          if [ -z "$2" ]
          then
            echo "repartition with --dest-broker-list|-b option without value"
            usage
            exit 1
          fi
          brokerList="$2"
          shift 2
        ;;
      --dry-run)
        dryRun="yes"
        shift 1
        ;;
      --verify)
        verify="yes"
        shift 1
        ;;
      --wait-finished)
        if [ -z "$2" ]
        then
          echo "repartition with --wait-finished option without value"
          usage
          exit 1
        fi
        waitFinishedTimeout="$2"
        shift 2
        ;;
      --format-plan)
        formatPlan="yes"
        shift 1
        ;;
      *)
        echo "ERROR unknown option $1 on repartition command"
        usage
        exit 1
        ;;
    esac
  done

  if [ -z "$brokerList" ]
  then
    brokerList=$(list_brokers | tr -d '][ ')
  fi

  echo "### Topics \"$topics\" will be 'repartitioned' to \"$brokerList\" brokers"

  # temporal dir
  local tempDir=$(mktemp -d)
  cd "$tempDir"

  #Build json file with topics name configured
  generate_topics_json $topics > topics-to-move.json

  # Generate repartiton plan
  kafka-reassign-partitions.sh \
    --zookeeper "${ZOOKEEPER_ENTRY_POINT}" \
    --topics-to-move-json-file topics-to-move.json \
    --broker-list "$brokerList" \
    --generate \
  > repartition-plan.stdout

  # Check pre-requisites format to split file
  local lines="$(cat repartition-plan.stdout | wc -l)"
  if [ "$lines" != "5" ]
  then
    echo "ERROR: expected 5 lines on repartition plan but get $lines":
    echo "----------"
    cat repartition-plan.stdout
    echo "----------"
    exit 1
  fi

  # Extracting current and propossed partion state
  local repartictionCurrentJson=$(cat repartition-plan.stdout | egrep -e "Current partition replica assignment" -A1 | tail -1)
  local repartictionProposedJson=$(cat repartition-plan.stdout | egrep -e "Proposed partition reassignment configuration" -A1 | tail -1)

  if [ -z "$repartictionCurrentJson" -o -z "$repartictionProposedJson" ]
  then
    echo "ERROR: When extract information from repartition-plan.stdout:
expected format:
Current partition replica assignment
{ .... JSON_DATA ...}
Proposed partition reassignment configuration
{ .... JSON_DATA ...}"

    echo "Current value"
    echo "----------"
    cat repartition-plan.stdout
    echo "----------"
    exit 1
  fi

  echo "$repartictionCurrentJson" | jq -S . - > repartiton-current-format.json
  echo "$repartictionProposedJson" | jq -S . - > repartiton-proposed-format.json

  if diff --unified repartiton-current-format.json repartiton-proposed-format.json > /dev/null
  then
    echo "INFO: Current partition replica is the same like proposed. NOTHING to do"
    exit 0
  fi
  echo "### Working plan"
  echo ">>From"
  if [ "yes" == "$formatPlan" ]
  then
    cat repartiton-current-format.json
  else
    echo "$repartictionCurrentJson"
  fi
  echo ">>To"
  if [ "yes" == "$formatPlan" ]
  then
    cat repartiton-proposed-format.json
  else
    echo "$repartictionProposedJson"
  fi

  if [ "yes" == "$dryRun" ]
  then
    echo "### Dry run mode. End"
    echo "Use next data (json between \"-----\") to execute this plan with repartition-with-plan command"
    echo "-----"
    echo "$repartictionProposedJson"
    echo "-----"
    echo "Rollback execution data (json between \"-----\"), only if will be applied"
    echo "-----"
    echo "$repartictionCurrentJson"
    echo "-----"
    exit 0
  fi

  repartition_with_plan "$repartictionProposedJson" "$tempDir"

  # Verify
  if [ "yes" == "$verify" ]
  then
    verify_repartition "$repartictionProposedJson" "$tempDir" "$waitFinishedTimeout"
  fi

  cd - > /dev/null
  rm -fr "$tempDir"
}

# $1 Array with topics
generate_topics_json(){
  local topics=()
  while [ -n "$1" ]
  do
    topics=(${topics[@]} $1)
    shift 1
  done

  #Header of file
  echo -n '{"version":1, "topics": ['
  # Each topic
  for i in ${!topics[*]}
  do
    # For first item we does not prefix with json array separator (,)
    if [ "$i" -eq "0" ]
    then
      printf "{\"topic\": \"%s\"}" ${topics[$i]}
    else
      printf ", {\"topic\": \"%s\"}" ${topics[$i]}
    fi
  done
  # End of file
  echo ']}'
}

# $1 json string with plan
# $2 (Optional) temporal path used to save files. If not defined temporal path
# will be created and removed when finished. If it is provided, path will not be
# erased at end.
repartition_with_plan(){
  if [ -z "$1" ]
  then
    echo "ERROR: repartition-with-plan without JSON data"
    usage
    exit 1
  fi

  local tempDir="$2"
  local deleteTempDir="no"
  if [ -z "$tempDir" ]
  then
    tempDir=$(mktemp -d)
    deleteTempDir="yes"
  fi

  echo "$1" > "$tempDir/repartiton-plan.json"
  # Executing plan
  echo "### Executing plan"
  kafka-reassign-partitions.sh \
    --zookeeper "${ZOOKEEPER_ENTRY_POINT}" \
    --reassignment-json-file "$tempDir/repartiton-plan.json" \
    --execute \
    | tee $tempDir/repartition-with-plan.stdout

  if [ "$(cat $tempDir/repartition-with-plan.stdout | wc -l)" -ne "6" ]
  then
    echo "ERROR: Number of output lines of repartition command are not the expected:"
    echo "=============================================="
    cat $tempDir/repartition-with-plan.stdout
    echo "=============================================="
    exit 1
  fi
  local repartictionRollbackJson="$(cat $tempDir/repartition-with-plan.stdout | egrep -e "Current partition replica assignment" -A2 | tail -1)"

  if [ -z "$repartictionRollbackJson" ]
  then
    echo "ERROR: when parse repartition command output:"
    echo "=============================================="
    cat $tempDir/repartition-with-plan.stdout
    echo "=============================================="
    exit 1
  fi

  echo "Use next data (json between \"-----\") to verify current realocation. See verify-repartition command"
  echo "-----"
  cat "$tempDir/repartiton-plan.json"
  echo "-----"
  echo "Or use next data (json between \"-----\") to ROLL-BACK current partition allocation"
  echo "-----"
  echo "$repartictionRollbackJson"
  echo "-----"

  if [ "yes" == "$deleteTempDir" ]
  then
    rm -fr "$tempDir"
  fi
}

# $1 json string with plan
# $2 (Optional) temporal path used to save files. If not defined temporal path
# $3 (Optional, Int) if it is not empty wait for all partitions was realocated. Or
#   timeout is triggered.
# will be created and removed when finished. If it is provided, path will not be
# erased at end.
verify_repartition(){

  local repartitionPlanJson="$1"
  if [ -z "$repartitionPlanJson" ]
  then
    echo "ERROR: verify-repartition without plan"
    usage
    exit 1
  fi

  local tempDir="$2"
  local deleteTempDir="no"
  if [ -z "$tempDir" ]
  then
    tempDir=$(mktemp -d)
    deleteTempDir="yes"
  fi

  local timeout="$3"

  echo "### Verification"
  echo -n "$repartitionPlanJson" > "$tempDir/repartiton-verify-plan.json"
  kafka-reassign-partitions.sh \
    --zookeeper "${ZOOKEEPER_ENTRY_POINT}" \
    --reassignment-json-file "$tempDir/repartiton-verify-plan.json" \
    --verify \
  > "$tempDir/verification.stdout"

  if [ -n "$timeout" ]
  then
    echo "### Waiting for repartition finished or timeout of $timeout secs"
    iterations="$(( timeout / 5))"
    while [ "$iterations" -gt "0" ]
    do
      local status="$(cat "$tempDir/verification.stdout" | egrep -oe "(still in progress)|completed" | sort | uniq -c)"
      echo "-------"
      echo "$status"
      if echo "$status" | fgrep "still" > /dev/null
      then
        sleep 5
        kafka-reassign-partitions.sh \
          --zookeeper "${ZOOKEEPER_ENTRY_POINT}" \
          --reassignment-json-file "$tempDir/repartiton-verify-plan.json" \
          --verify \
        > "$tempDir/verification.stdout"
        iterations=$((iterations - 1))
      else
        # No more partitions pending
        echo "INFO: All partitons reallocated"
        break
      fi
    done

    if [ "$iterations" -eq 0 ]
    then
      echo "WARN: Timeout reached when wait for realocation finished"
    fi
  fi

  if [ "yes" == "$deleteTempDir" ]
  then
    rm -fr "$tempDir"
  fi
}

wait_for_service_up(){
    if [ -n "$WAIT_FOR_SERVICE_UP" ]; then
      local services=""
      #Set -wait option to use with docerize
      for service in $WAIT_FOR_SERVICE_UP; do
        services="$services -wait $service"
      done
      echo "Waiting till services $WAIT_FOR_SERVICE_UP are accessible (or timeout: $WAIT_FOR_SERVICE_UP_TIMEOUT)"
      dockerize $services -timeout "$WAIT_FOR_SERVICE_UP_TIMEOUT"
    fi
}

keep_alive() {
    if [ -n "$KEEP_ALIVE_SLEEP_TIME" ]; then
      if [ "$KEEP_ALIVE_SLEEP_TIME" -gt 0 ];
      then
        echo "Entering in a KEEP-ALIVE mode sleep $KEEP_ALIVE_SLEEP_TIME secs between iterations"
        while true;
        do
          sleep $KEEP_ALIVE_SLEEP_TIME
        done
      else
        echo "WARNING KEEP_ALIVE_SLEEP_TIME value '$KEEP_ALIVE_SLEEP_TIME' is defined but is not greather than 0. Keep alive option deactivated"
      fi
    fi
}

wait_for_service_up

case $1 in
  list-brokers)
    shift
    list_brokers $@
    ;;
  list-topics)
    list_topics
    ;;
  wait-for-topics)
    shift
    wait_for_topics $@
    ;;
  create-topic)
    shift
    create_topics $@
    ;;
  delete-topic)
    shift
    delete_topics $@
    ;;
  describe-topic)
    shift
    describe_topic $@
    ;;
  consume)
    shift
    consume $@
    ;;
  produce)
    shift
    produce $@
    ;;
  repartition)
    shift
    repartition $@
    ;;
  repartition-with-plan)
    shift
    repartition_with_plan $@
    ;;
  verify-repartition)
    shift
    verify_repartition $@
    ;;
  *)
    usage
    exit 1
    ;;
esac

keep_alive
