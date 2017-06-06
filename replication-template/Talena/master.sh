echo "Arguments : $@" > /tmp/master.log
echo `ls -l` >> /tmp/master.log
./prepare-master-node.sh $@
echo "Completed master processing..." >> /tmp/master.log
