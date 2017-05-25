#!/bin/bash
# File: clwatch.sh
# Description: watch for craiglist ads and automatically notify the user






####################################################
##### User Config Settings - Edit these lines! #####
####################################################
DIR="/home/dir/scripts/clwatch_files"        # the directory where you want to store files from the script
mkdir -p ${DIR} # Make the directoryi if it doesn't exist

# Define Search terms - create as many or as little as you like!
echo scuba >> ${DIR}/clwatch_search_terms_tmp.txt
echo kittens >> ${DIR}/clwatch_search_terms_tmp.txt
# Multiple search term example(make sure to use a plus sign in-between search terms):
echo red+ferrari >> ${DIR}/clwatch_search_terms_tmp.txt


# Define Locations to search (these are in the craigslist URL (EX: http://phoenix.craigslist.org)
echo phoenix >> ${DIR}/clwatch_locations_tmp.txt
echo denver >> ${DIR}/clwatch_locations_tmp.txt

CHECK_FOR_REMOVED_LISTINGS=1  # =1 will check when listings are removed; =0 won't!
VERBOSE=1                     # =1 will notify you when listings change; =0 will only notify you of new listings

# Configure Mutt to send an email
EMAIL_ADDR="your.email@gmail.com"
HOME_DIR="/home/dir"  # Directory where .muttrc is located
${HOME_DIR}/./.muttrc # if running this script as root you have to give root your mutt configuration





##############################################################################
##### Don't edit the lines below unless you laugh in the face of danger! #####
##############################################################################

# function to send mutt email
function send_mutt_email_fn {
   MESSAGE_TITLE="${1}"
   MESSAGE_BODY="${2}"
   mutt -n -s "${MESSAGE_TITLE}"  -- "${EMAIL_ADDR}" < "${MESSAGE_BODY}"
}
# # function to post to twitter
# function send_tweet_fn {
#    # idea for later
# }
# 
# # function to send an sms
# function send_text_message_fn {
#    # idea for later
# }

# Choose what type of message to send
function send_message_fn {
   MESSAGE_TITLE="${1}" # store the first argument as the message title
   MESSAGE_BODY="${2}"  # store the second argument as file with the message body

   send_mutt_email_fn "${MESSAGE_TITLE}" "${MESSAGE_BODY}"     # send an email
   #send_tweet_fn ${1} ${2}         # post to twitter
   #send_text_message_fn ${1} ${2}  # send an sms
}

# Store the current date and time
THE_DATE=`date`

# Choose which list to compare new listings against
if [[ "${VERBOSE}" == "1" ]];then
   PREV_LIST="_prev_list.txt"
fi
if [[ "${VERBOSE}" == "0" ]];then
   PREV_LIST="_listing_history.txt"
fi

# Loop through every location for each search term
while read SEARCH_TERM
   do
   while read LOCATION
      do


      ####################################
      ##### Get the Current Listings #####
      ####################################
      # Remove temp file if it exists
      if [ -f ${DIR}/${SEARCH_TERM}${LOCATION}_curr_list.txt ];then
         rm -rf ${DIR}/${SEARCH_TERM}${LOCATION}_curr_list.txt
      fi
      # Write all the current listings to temp file
      curl -s "http://${LOCATION}.craigslist.org/search/sss?sort=date&query=${SEARCH_TERM}&format=rss" \
              | grep -E '<item rdf:about=|<title>' \
              | sed s'/<item rdf:about="//'g \
              | sed s'/<title><!\[CDATA\[/ /'g \
              | sed s'/">//'g  \
              | sed s'/]]><\/title>//'g \
              | sed s'/<title>craigslist '"${LOCATION}"' | for sale \/ wanted search \"'"${SEARCH_TERM}"'\"<\/title>/ /' \
              | sed -n -e ":a" -e "$ s/html\n/html /gp;N;b a" \
              >> ${DIR}/${SEARCH_TERM}${LOCATION}_curr_list.txt

     
      #################################
      ##### Test for New Listings #####
      #################################
      # Loop through every line of the current listings tmp file
      NEW_LISTING_FOUND=1
      while read CURR_LINE
         do
         # Loop through every line of the previous listings file
         while read PREV_LINE  
            do  
               # Compare current listings file with previous listings file to find new listings
               if [[ "${CURR_LINE}\n" == "${PREV_LINE}\n" ]];then
                  NEW_LISTING_FOUND=0
                  break
               fi
         done < ${DIR}/${SEARCH_TERM}${LOCATION}${PREV_LIST}
         
         if [ ${NEW_LISTING_FOUND} == 1 ];then
            echo "${CURR_LINE}" >> ${DIR}/${SEARCH_TERM}${LOCATION}_new_listing.txt
            echo "${CURR_LINE}" >> ${DIR}/${SEARCH_TERM}${LOCATION}_listing_history.txt
         fi
         NEW_LISTING_FOUND=1
      done < ${DIR}/${SEARCH_TERM}${LOCATION}_curr_list.txt

      # Send message if new listing was found
      if [ -f ${DIR}/${SEARCH_TERM}${LOCATION}_new_listing.txt ];then
         date >> ${DIR}/${SEARCH_TERM}${LOCATION}_new_listing.txt
         send_message_fn "New ${SEARCH_TERM} ${LOCATION} Post: ${THE_DATE}" "${DIR}/${SEARCH_TERM}${LOCATION}_new_listing.txt"
         rm -f ${DIR}/${SEARCH_TERM}${LOCATION}_latest_new_listing.txt
         cp ${DIR}/${SEARCH_TERM}${LOCATION}_new_listing.txt ${DIR}/${SEARCH_TERM}${LOCATION}_latest_new_listing.txt
      fi
      
      
      #####################################
      ##### Test for Removed Listings #####
      #####################################
      if [[ "${CHECK_FOR_REMOVED_LISTINGS}" == "1" ]];then
         # Loop through every line of the previous listings
         REMOVED_LISTING_FOUND=1 
         while read PREV_LINE
            do
            # Loop through every line of the current listings
            while read CURR_LINE  
               do  
                  if [[ "${PREV_LINE}\n" == "${CURR_LINE}\n" ]];then
                     REMOVED_LISTING_FOUND=0
                     break
                  fi
            done < ${DIR}/${SEARCH_TERM}${LOCATION}_curr_list.txt
            if [ ${REMOVED_LISTING_FOUND} == 1 ];then
               echo "${PREV_LINE}" >> ${DIR}/${SEARCH_TERM}${LOCATION}_rmv_listing.txt
            fi
            REMOVED_LISTING_FOUND=1
         done < ${DIR}/${SEARCH_TERM}${LOCATION}_prev_list.txt
      fi

      # Send message if removed listing was found
      if [ -f ${DIR}/${SEARCH_TERM}${LOCATION}_rmv_listing.txt ];then
         date >> ${DIR}/${SEARCH_TERM}${LOCATION}_rmv_listing.txt
         send_message_fn "Removed ${SEARCH_TERM} ${LOCATION} Post: ${THE_DATE}" "${DIR}/${SEARCH_TERM}${LOCATION}_rmv_listing.txt"
         rm -f ${DIR}/${SEARCH_TERM}${LOCATION}_latest_rmv_listing.txt
         cp ${DIR}/${SEARCH_TERM}${LOCATION}_rmv_listing.txt ${DIR}/${SEARCH_TERM}${LOCATION}_latest_rmv_listing.txt
      fi
 
    
      #####################
      ##### Clean Up! #####
      #####################
      # Replace the previous list with the current list
      mv -f ${DIR}/${SEARCH_TERM}${LOCATION}_curr_list.txt ${DIR}/${SEARCH_TERM}${LOCATION}_prev_list.txt
      # Remove temporary new listing files
      if [ -f ${DIR}/${SEARCH_TERM}${LOCATION}_new_listing.txt ];then
         rm -rf $DIR/${SEARCH_TERM}${LOCATION}_new_listing.txt
      fi
      if [ -f ${DIR}/${SEARCH_TERM}${LOCATION}_rmv_listing.txt ];then
         rm -rf ${DIR}/${SEARCH_TERM}${LOCATION}_rmv_listing.txt
      fi
   
   done < ${DIR}/clwatch_locations_tmp.txt
done < ${DIR}/clwatch_search_terms_tmp.txt



# Clean up temp files
if [ -f ${DIR}/clwatch_search_terms_tmp.txt ];then
   rm -rf $DIR/clwatch_search_terms_tmp.txt
fi
if [ -f ${DIR}/clwatch_locations_tmp.txt ];then
   rm -rf ${DIR}/clwatch_locations_tmp.txt
fi
