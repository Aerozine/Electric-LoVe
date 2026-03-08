mesh :
	./gmsh/bin/python geometry.py -nopopup

clean :
	rm -rf *.db *.db.json *.msh *.pre *.res res 

view :
	gmsh LoVe.brep LoVe.msh
# order cause trouble 
# if step and msh order fucked up
