mesh :
	./gmsh/bin/python geometry.py

clean :
	rm -rf *.db *.db.json *.msh *.pre *.res res *.csv generated_common.pro *.step *.brep
run_elec:
	getdp LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2
run_mag:
	getdp LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 1 -solve Magnetoquasistatics -pos Post_Mag -v2
# order need to be taken into acount to hint gmsh wich geometry has wich mesh
view :
	gmsh Love.msh res/az.pos res/bm.pos res/v.pos res/em.pos
# order cause trouble 
# if step and msh order fucked up
