#!/bin/bash

#### GET ALL PROJECTS THAT THE AUTHENTICATED USER HAS ACCESS TO
PROJECTS_TO_INSPECT=$(gcloud projects list --format="value(projectId)")

####### ALTERNATIVELY, MANUALLY SPECIFY A LIST OF PROJECTS
####### INSERT HERE YOUR PROJECTS ####################################
PROJECTS_TO_INSPECT=("MY_PROJECT_ID_1" "MY_PROJECT_ID_2" )
########################################################################

# Declare an array of recommenders
declare -a recommenderTypes=("google.compute.address.IdleResourceRecommender" "google.compute.disk.IdleResourceRecommender" "google.compute.instance.IdleResourceRecommender" "google.compute.image.IdleResourceRecommender" "google.cloudsql.instance.IdleRecommender" "google.cloudsql.instance.OverprovisionedRecommender")

get_cost_rec_id () {
    echo "getting rec details"
    local_dollar_amt=$(gcloud recommender recommendations describe $1 --project=$2 --location=$3 --recommender=$4 --format="value(primaryImpact.costProjection.cost.units)")
    echo "dollar_amt=$local_dollar_amt"
    local_dollar_amt=$(($local_dollar_amt*(-1)))
    echo "dollar_amt=$local_dollar_amt"
}

set_locations () {
    gcloud config set project $1

    locations=("global")

    zones=()
    for zone in $(gcloud compute zones list --format="value(NAME)" --quiet)
    do
        zones+=($zone)
    done

    regions=()
    for region in $(gcloud compute regions list --format="value(NAME)" --quiet)
    do
        regions+=($region)
    done

    locations+=("${zones[@]}" "${regions[@]}")

    echo "locations=${locations[@]}"
    echo "total number of locations to search:" ${#locations[@]}
}

total_dollar_amt=0

for PROJ in $PROJECTS_TO_INSPECT
do
    echo "PROJ=$PROJ"

    set_locations $PROJ
    
    gcloud config set project $PROJ --quiet
    gcloud services enable recommender.googleapis.com --quiet

    for location in ${locations[@]};
    do
        for recommender in ${recommenderTypes[@]};
        do
            echo "recommender=$recommender"
            REC_LIST=$(gcloud recommender recommendations list --location=$location --recommender=$recommender --project=$PROJ --quiet --format="value(RECOMMENDATION_ID)")
            for REC_ID in $REC_LIST
            do
                get_cost_rec_id $REC_ID $PROJ $location "google.compute.address.IdleResourceRecommender"
                total_dollar_amt=$(($total_dollar_amt+$local_dollar_amt))
                echo "total_dollar_amt=$total_dollar_amt"
            done
        done
    done
done

echo "\n"
echo "FINAL_DOLLAR_AMOUNT=$total_dollar_amt"