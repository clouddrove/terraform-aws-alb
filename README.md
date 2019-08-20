AWS ALB
==============

This module is for create alb with related resources.   

###### main.tf 
contain resource code for alb.   

###### variables.tf 
contain variables declaration. all variables are empty by default. we will define or put value to variables in equls.tf (main file for infrastructure). these are input vars.  

###### outputs.tf 
is alse contain variables but we will these variables for output like ec2 instance id.  

##  Infrastructure creats by this module  

1. Alb  
2. Alb listener  
3. Alb target group  
4. Alb target group attachment.   
 



