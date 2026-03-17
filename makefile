init:
	python3 -m venv gmsh 
	./gmsh/bin/pip install -r requirements.txt
mesh :
	./gmsh/bin/python geometry.py

clean :
	rm -rf *.db *.db.json *.msh *.pre *.res res *.csv generated_common.pro *.step *.brep
run_elec:
	getdp LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2
run_mag:
	getdp LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 1 -solve Magnetoquasistatics -pos Post_Mag -v2

view :
	gmsh LoVe.pro
