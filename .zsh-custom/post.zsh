# remove duplicates from PATH
export PATH=$(printf %s "$PATH" \
     | awk -vRS=: -vORS= '{
         gsub(/\/$/, "", $0);  # Remove trailing slash
         if (!seen[$0]++) {
           if (NR > 1) printf ":";
           printf "%s", $0;
         }
       }')
