shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 pigment : source_color = vec4(0.35, 0.20, 0.14, 1.0);
// 0 timber, 1 masonry, 2 ceramic, 3 plaster, 4 silk, 5 stone, 6 bronze, 7 earth, 8 thatch, 9 mat
uniform int surface_kind = 0;
uniform int grain_axis = 1;
// Timber: 0 bare, 1 fine lines, 2 diamond band. Mat: 0 reeds, 1 basket, 2 diagonal twill.
uniform int surface_pattern = 0;
uniform bool glazed = false;
uniform bool lacquered = false;
// Authored street-shop palette: coarse material cues survive, microcontrast recedes.
// Other materials retain the original response at false.
uniform bool quiet_surface = false;
// 离线 PBR 纹理可替换来源；缺失时使用下方原程序材质。
uniform bool pbr_enabled = false;
uniform sampler2D base_color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D end_color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D end_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D end_orm_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 texture_reference : source_color = vec4(0.5,0.5,0.5,1.0);
uniform vec4 end_reference : source_color = vec4(0.5,0.5,0.5,1.0);
uniform vec2 tile_size_m = vec2(1.0);
uniform vec2 end_size_m = vec2(0.42);
uniform float texture_scale : hint_range(0.25,4.0) = 1.0;
uniform float normal_strength : hint_range(0.0,2.0) = 0.8;
uniform float surface_age : hint_range(0.0,1.0) = 0.3;
uniform float surface_variation : hint_range(0.0,1.0) = 0.22;
uniform float surface_dust : hint_range(0.0,1.0) = 0.15;
// 可替换的独占 UV 件选择 1；原生构件默认按局部米制坐标投射。
uniform int mapping_mode = 0;
uniform float material_seed = 0.0;
instance uniform float surface_seed = 0.5;
varying vec3 local_p;
varying vec3 metric_p;
varying vec3 local_normal;
varying float piece_seed;
varying float piece_axis;
varying float up_facing;

struct SurfaceSample {
	vec3 color;
	vec3 normal;
	vec3 orm;
};

// 从每个投射平面的导数重建切线，再统一到视空间；不直接混合 RGB 法线。
vec3 projected_normal(vec3 encoded, vec2 uv, vec3 position, vec3 base_normal) {
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec3 px = dFdx(position);
	vec3 py = dFdy(position);
	float determinant = dx.x*dy.y-dx.y*dy.x;
	if (abs(determinant)<0.0000000001) { return base_normal; }
	vec3 t = (px*dy.y-py*dx.y)*sign(determinant);
	vec3 b = (-px*dy.x+py*dx.x)*sign(determinant);
	t -= base_normal*dot(base_normal,t);
	b -= base_normal*dot(base_normal,b);
	t /= max(length(t),0.000001);
	b /= max(length(b),0.000001);
	vec2 xy = (encoded.xy*2.0-1.0)*normal_strength;
	float z = sqrt(max(0.01,1.0-dot(xy,xy)));
	// PNG 行向下，NormalGL 的 +Y 朝上，因此使用 -dP/dV。
	return normalize(base_normal*z+t*xy.x-b*xy.y);
}

SurfaceSample sample_surface(vec2 uv, bool end_grain, vec3 position, vec3 base_normal) {
	SurfaceSample value;
	vec3 n;
	if (end_grain) {
		value.color = texture(end_color_map,uv).rgb/max(end_reference.rgb,vec3(0.015));
		n = texture(end_normal_map,uv).rgb;
		value.orm = texture(end_orm_map,uv).rgb;
	} else {
		value.color = texture(base_color_map,uv).rgb/max(texture_reference.rgb,vec3(0.015));
		n = texture(normal_map,uv).rgb;
		value.orm = texture(orm_map,uv).rgb;
	}
	value.normal = projected_normal(n,uv,position,base_normal);
	return value;
}

SurfaceSample material_surface(vec3 position, vec3 base_normal, vec2 source_uv) {
	vec2 offset = vec2(piece_seed*0.67,piece_seed*0.43);
	if (mapping_mode == 1) { return sample_surface(source_uv*texture_scale,false,position,base_normal); }
	vec3 p = metric_p*texture_scale;
	vec3 weights = pow(abs(normalize(local_normal)),vec3(6.0));
	weights /= max(weights.x+weights.y+weights.z,0.00001);
	vec2 xuv = p.zy;
	vec2 yuv = p.xz;
	vec2 zuv = p.xy;
	int axis = int(round(piece_axis));
	bool wood = surface_kind == 0;
	if (wood && axis == 0) { yuv = p.zx; zuv = p.yx; }
	if (wood && axis == 2) { xuv = p.yz; yuv = p.xz; }
	bool ex = wood && axis == 0;
	bool ey = wood && axis == 1;
	bool ez = wood && axis == 2;
	SurfaceSample a = sample_surface(xuv/(ex ? end_size_m : tile_size_m)+offset,ex,position,base_normal);
	SurfaceSample b = sample_surface(yuv/(ey ? end_size_m : tile_size_m)+offset,ey,position,base_normal);
	SurfaceSample c = sample_surface(zuv/(ez ? end_size_m : tile_size_m)+offset,ez,position,base_normal);
	SurfaceSample value;
	value.color = a.color*weights.x+b.color*weights.y+c.color*weights.z;
	value.orm = a.orm*weights.x+b.orm*weights.y+c.orm*weights.z;
	value.normal = normalize(a.normal*weights.x+b.normal*weights.y+c.normal*weights.z);
	return value;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),
		mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),
		mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1)),f.x),f.y),f.z);
}
// Fade subpixel frequencies instead of turning fine pores into distant sparkle.
float detail_visibility(vec3 p) {
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	return 1.0-smoothstep(0.35, 1.4, footprint);
}
float filtered_noise(vec3 p) {
	return mix(0.5, noise3(p), detail_visibility(p));
}
// Work in pattern cycles, averaging details that no longer cover a pixel.
float filtered_stripe(float phase, float half_width) {
	float footprint = max(fwidth(phase),0.0001);
	float edge = abs(fract(phase+0.5)-0.5);
	float stripe = 1.0-smoothstep(half_width-footprint*0.6,half_width+footprint*0.6,edge);
	return mix(half_width*2.0,stripe,1.0-smoothstep(0.3,1.2,footprint));
}
float filtered_wave(float phase) {
	return mix(0.5,0.5+0.5*cos(6.28318530718*phase),
		1.0-smoothstep(0.3,1.2,fwidth(phase)));
}
void vertex() {
	local_p = VERTEX;
	// Local axes keep grain attached when moving or rotating the entire building.
	metric_p = VERTEX * vec3(length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_normal = NORMAL;
	piece_axis = UV2.y>6.5 && UV2.x>0.5 ? UV2.x-1.0 : float(grain_axis);
	up_facing = dot(normalize(MODEL_NORMAL_MATRIX*NORMAL),vec3(0.0,1.0,0.0));
	// MultiMesh uses custom data; ordinary instances share the same material.
	piece_seed = INSTANCE_CUSTOM.a > 0.5 ? INSTANCE_CUSTOM.r : surface_seed;
	piece_seed = fract(piece_seed+mod(material_seed,1024.0)*0.61803398875);
}
void fragment() {
	vec3 p = metric_p + vec3(piece_seed*13.7, piece_seed*7.3, piece_seed*19.1);
	vec3 face = normalize(local_normal);
	float cloud = noise3(p*2.6);
	float grit = filtered_noise(p*100.0);
	float relief = 0.0;
	float cavity = 0.0;
	vec3 color = pigment.rgb;
	float rough = 0.86;
	float metal = 0.0;
	float coat = 0.0;
	float quiet = quiet_surface ? 1.0 : 0.0;
	if (!pbr_enabled || surface_kind==1 || surface_pattern>0 || lacquered || glazed) {
	if (surface_kind == 0) {
		vec3 g = metric_p;
		float end_face = abs(face.x);
		if (int(round(piece_axis)) == 1) { g = metric_p.yxz; end_face = abs(face.y); }
		if (int(round(piece_axis)) == 2) { g = metric_p.zyx; end_face = abs(face.z); }
		g.yz += vec2(0.11+piece_seed*0.13, 0.09-piece_seed*0.19);
		float warp = noise3(g*vec3(0.65,7.0,7.0));
		float grain = filtered_noise(g*vec3(1.3,155.0,155.0)+warp*1.7);
		float fiber = filtered_noise(g*vec3(0.8,35.0,35.0)+warp);
		float ring_phase = length(g.yz+vec2(warp*0.008))*1400.0;
		float rings = mix(0.5, 0.5+0.5*sin(ring_phase),
			1.0-smoothstep(1.0,5.0,fwidth(ring_phase)));
		float end_mask = smoothstep(0.65,0.95,end_face);
		float split = smoothstep(0.68,0.82,fiber)*smoothstep(0.56,0.72,grain);
		float weather = smoothstep(0.35,0.78,cloud*0.65+fiber*0.35);
		vec3 bare = lacquered ? vec3(0.115,0.067,0.035) : pigment.rgb;
		bare *= mix((0.77+0.29*fiber+0.16*grain)*(0.91+piece_seed*0.18),
			(0.88+0.12*fiber+0.06*grain)*(0.975+piece_seed*0.05),quiet);
		bare *= mix(1.0,mix(0.72+0.36*rings,0.90+0.20*rings,quiet),end_mask);
		bare = mix(bare, vec3(0.070,0.055,0.038),weather*mix(0.30,0.12,quiet));
		// Intermittent longitudinal splits and coarse grain survive the close view;
		// subpixel fibres remain filtered instead of adding shimmer at a distance.
		float fissure = smoothstep(0.72,0.87,filtered_noise(g*vec3(0.30,88.0,88.0)+warp*0.35));
		fissure *= smoothstep(0.43,0.67,noise3(g*vec3(4.0,3.0,3.0)));
		bare *= 1.0-split*mix(0.36,0.12,quiet)-fissure*mix(0.52,0.20,quiet);
		color = bare;
		rough = mix(0.73+0.19*weather,0.82+0.10*weather,quiet);
		relief = mix(grain*0.00045+fiber*0.00075-split*0.0008-fissure*0.002+end_mask*rings*0.00035,
			grain*0.00014+fiber*0.00030-split*0.00018-fissure*0.0005+end_mask*rings*0.00012,quiet);
		cavity = split*mix(0.19,0.05,quiet)+fissure*mix(0.28,0.08,quiet);
		if (lacquered) {
			float chipped = smoothstep(0.57,0.74,cloud*0.60+fiber*0.30+grit*0.10);
			chipped = max(chipped,end_mask*0.4);
			vec3 lacquer = pigment.rgb*(0.81+0.22*cloud+0.10*piece_seed);
			color = mix(lacquer,bare,chipped);
			rough = mix(0.33+0.18*cloud,rough,chipped);
			relief = mix(grit*0.00008,relief,chipped)-chipped*0.00025;
			coat = (1.0-chipped)*0.38;
		}
		if (surface_pattern > 0) {
			// A restrained geometric band on beam sides, attached to local timber
			// coordinates. This is an art variant, not a traced historical painting.
			float transverse = abs(face.y)>0.65 ? metric_p.z : metric_p.y;
			float edge = abs(abs(transverse)-0.067);
			float aa = max(fwidth(edge),0.0006);
			float ink = 1.0-smoothstep(0.0025-aa,0.0025+aa,edge);
			float visible = 1.0-smoothstep(0.006,0.028,fwidth(transverse));
			if (surface_pattern == 2) {
				float diamond = abs(fract(metric_p.x/0.28+0.5)-0.5)*2.0+abs(transverse)/0.058;
				float diamond_aa = max(fwidth(diamond),0.015);
				float band = 1.0-smoothstep(0.045-diamond_aa,0.045+diamond_aa,abs(diamond-1.0));
				ink = max(ink,band*(1.0-smoothstep(0.060,0.071,abs(transverse))));
				visible *= 1.0-smoothstep(0.25,1.2,fwidth(metric_p.x/0.28));
			}
			float faded = 0.48+0.34*cloud;
			ink *= visible*faded*(1.0-split*0.60);
			color = mix(color,vec3(0.24,0.205,0.143)*(0.8+cloud*0.20),ink*0.72);
			relief += ink*0.00012;
		}
	} else if (surface_kind == 1) {
		vec3 n = abs(face);
		bool paving = n.y > max(n.x,n.z);
		vec2 plane = paving ? metric_p.xz : (n.x > n.z ? metric_p.zy : metric_p.xy);
		vec2 size = paving ? vec2(0.84,0.52) : vec2(0.46,0.18);
		vec2 grid = plane/size;
		grid.x += 0.5*mod(floor(grid.y),2.0);
		vec2 distance_to_edge = min(fract(grid),1.0-fract(grid))*size;
		float edge = min(distance_to_edge.x,distance_to_edge.y);
		float aa = max(fwidth(edge),0.0005);
		float joint = smoothstep(0.003-aa,0.008+aa,edge);
		float block = hash3(vec3(floor(grid),piece_seed*17.0));
		color *= mix(0.78+0.30*block+0.10*cloud+0.05*grit,0.90+0.10*block+0.06*cloud+0.02*grit,quiet);
		color = mix(pigment.rgb*mix(0.40,0.70,quiet),color,joint);
		relief = joint*mix(0.002,0.0008,quiet)+grit*mix(0.00035,0.00012,quiet);
		cavity = (1.0-joint)*mix(0.30,0.12,quiet);
	} else if (surface_kind == 2) {
		float fired = noise3(p*vec3(5.0,10.0,5.0));
		float pores = smoothstep(0.62,0.79,grit);
		color *= mix(0.78+0.24*piece_seed+0.15*cloud+0.08*fired,0.90+0.06*piece_seed+0.08*cloud+0.04*fired,quiet);
		color = mix(color,color*vec3(1.21,1.05,0.82),smoothstep(0.56,0.79,fired)*mix(0.30,0.10,quiet));
		color *= 1.0-pores*(glazed ? 0.035 : mix(0.13,0.035,quiet));
		rough = glazed ? 0.30+0.18*cloud : mix(0.77+0.14*fired,0.85+0.07*fired,quiet);
		coat = glazed ? 0.30 : 0.0;
		relief = mix(grit*0.00035+fired*0.00045,grit*0.00008+fired*0.00020,quiet)*(glazed ? 0.30 : 1.0);
		cavity = pores*mix(0.12,0.025,quiet);
	} else if (surface_kind == 3) {
		float trowel = noise3(p*vec3(4.0,12.0,4.0));
		float mottling = noise3(p*vec3(2.3,4.8,2.3));
		float pits = smoothstep(0.65,0.82,grit);
		color *= 0.78+0.15*cloud+0.12*trowel;
		color = mix(color,color*vec3(0.68,0.63,0.53),smoothstep(0.50,0.77,mottling)*mix(0.40,0.18,quiet));
		rough = 0.93;
		relief = trowel*mix(0.0011,0.00055,quiet)+grit*mix(0.00040,0.00010,quiet)-pits*mix(0.0008,0.0002,quiet);
		cavity = pits*mix(0.14,0.035,quiet);
	} else if (surface_kind == 4) {
		float angle = atan(local_p.z,local_p.x);
		float seam = smoothstep(0.91,0.99,cos(12.0*angle));
		float hardware = smoothstep(1.43,1.55,abs(local_p.y)/max(length(local_p.xz),0.002));
		float weave = filtered_noise(p*vec3(160.0,210.0,160.0));
		color *= (0.82+0.18*cloud+0.06*weave)*(1.0-0.16*seam);
		color = mix(color,vec3(0.10,0.061,0.026),max(seam*0.48,hardware));
		EMISSION = color*0.16*(1.0-hardware);
		metal = hardware*0.72;
		rough = mix(0.84,0.48,hardware);
		relief = weave*0.00012;
	} else if (surface_kind == 7) {
		float layers = filtered_noise(p*vec3(3.0,38.0,3.0));
		float aggregate = filtered_noise(p*43.0);
		color *= 0.78+0.19*cloud+0.14*layers+0.10*aggregate;
		rough = 0.97;
		relief = aggregate*0.0018+layers*0.0008;
	} else if (surface_kind == 8) {
		float fiber = filtered_noise(p*vec3(230.0,65.0,2.5));
		float dry = noise3(p*vec3(12.0,8.0,1.2));
		float bundle = noise3(p*vec3(20.0,5.0,3.5));
		color *= 0.48+0.32*fiber+0.28*dry+0.16*bundle;
		color = mix(color,color*vec3(0.62,0.68,0.63),smoothstep(0.3,0.78,cloud)*0.38);
		rough = 0.93;
		relief = fiber*0.0012+bundle*0.001;
	} else if (surface_kind == 9) {
		// R19 uses X for width and Z for projection. A thin woven sheet has
		// orderly crossings and bindings, unlike the loose straw roof family.
		vec2 uv = metric_p.xz+vec2(piece_seed*0.033,piece_seed*0.021);
		float fiber = 0.5;
		float ridge = 0.5;
		float binding = 0.0;
		float strand_color = 0.5;
		if (surface_pattern == 0) {
			float reed_pitch = mix(0.018,0.008,quiet);
			ridge = filtered_wave(uv.x/reed_pitch);
			binding = filtered_stripe(uv.y/0.18,0.028);
			fiber = filtered_noise(vec3(uv.x*1250.0,uv.y*5.0,piece_seed*9.0));
			strand_color = noise3(vec3(floor(uv.x/reed_pitch),piece_seed*17.0,0.0));
			strand_color = mix(0.5,strand_color,1.0-smoothstep(0.3,1.0,fwidth(uv.x/reed_pitch)));
		} else {
			vec2 woven = uv;
			if (surface_pattern == 2) {
				woven = vec2(uv.x+uv.y,uv.y-uv.x)*0.70710678118;
			}
			vec2 grid = woven/0.032;
			vec2 cell = floor(grid);
			float over = mod(cell.x+cell.y,2.0);
			if (surface_pattern == 2) {
				over = step(1.5,mod(cell.x-cell.y,4.0));
			}
			float visible = detail_visibility(vec3(grid,0.0));
			ridge = mix(filtered_wave(grid.x-0.5),filtered_wave(grid.y-0.5),over);
			ridge = mix(0.5,ridge,visible);
			float fiber_x = filtered_noise(vec3(woven.x*1500.0,woven.y*5.0,piece_seed*9.0));
			float fiber_y = filtered_noise(vec3(woven.y*1500.0,woven.x*5.0,piece_seed*9.0));
			fiber = mix(fiber_x,fiber_y,over);
			fiber = mix(0.5,fiber,visible);
			strand_color = mix(0.5,0.40+over*0.20,visible);
			binding = (1.0-ridge)*0.32;
		}
		color *= mix((0.63+0.22*strand_color+0.17*cloud+0.15*ridge+0.08*fiber)*(1.0-binding*0.36),
			(0.87+0.06*strand_color+0.10*cloud+0.025*ridge+0.025*fiber)*(1.0-binding*0.13),quiet);
		color = mix(color,color*vec3(0.76,0.80,0.73),smoothstep(0.48,0.81,cloud)*mix(0.22,0.12,quiet));
		rough = 0.94;
		relief = ridge*mix(0.0016,0.00035,quiet)+fiber*mix(0.00022,0.00005,quiet)+binding*mix(0.00065,0.00008,quiet);
		cavity = (1.0-ridge)*mix(0.12,0.025,quiet)+binding*mix(0.15,0.035,quiet);
	} else if (surface_kind == 6) {
		float patina = smoothstep(0.44,0.76,cloud*0.75+grit*0.25);
		color *= 0.76+grit*0.23;
		color = mix(color,vec3(0.043,0.064,0.047),patina*0.62);
		metal = mix(0.85,0.27,patina);
		rough = mix(0.36,0.76,patina);
		relief = grit*0.00017;
	} else {
		float tooling = filtered_noise(p*vec3(48.0,9.0,48.0));
		color *= mix(0.84+0.13*cloud+0.09*grit+0.08*piece_seed,0.90+0.10*cloud+0.03*grit+0.03*piece_seed,quiet);
		rough = 0.83+0.10*cloud;
		relief = tooling*mix(0.0007,0.0003,quiet)+grit*mix(0.00045,0.00012,quiet);
	}
	}
	if (pbr_enabled) {
		SurfaceSample tex = material_surface(VERTEX,NORMAL,UV);
		vec3 aged = pigment.rgb*tex.color;
		float variation = (piece_seed-0.5)*surface_variation;
		aged *= 1.0+variation*0.36;
		float weather = smoothstep(0.35,0.78,cloud)*surface_age;
		aged = mix(aged,aged*vec3(0.72,0.76,0.74),weather*0.55);
		float dust = surface_dust*smoothstep(0.1,0.85,up_facing)*(0.35+0.65*cloud);
		aged = mix(aged,vec3(0.27,0.24,0.185),dust*0.26);
		if (surface_kind==1 || surface_pattern>0) {
			aged *= clamp(color/max(pigment.rgb,vec3(0.015)),vec3(0.35),vec3(1.4));
		}
		color = aged;
		rough = clamp(tex.orm.g+weather*0.06+dust*0.08,0.18,1.0);
		if (glazed) { rough = mix(0.24,0.46,cloud+weather*0.25); coat = 0.3; }
		if (lacquered) { rough = mix(0.32,rough,surface_age); coat = (1.0-surface_age)*0.38; }
		metal = tex.orm.b;
		cavity = max(cavity,1.0-tex.orm.r);
		NORMAL = tex.normal;
		if (surface_kind!=1 && surface_pattern==0) { relief = 0.0; }
	}
	// 回退程序高度与细小饰线仍以导数 bump 叠加。
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 rx = cross(dpdy,NORMAL);
	vec3 ry = cross(NORMAL,dpdx);
	float det = dot(dpdx,rx);
	vec3 gradient = (dFdx(relief)*rx+dFdy(relief)*ry)*sign(det)/max(abs(det),0.00000001);
	NORMAL = normalize(NORMAL-clamp(gradient,vec3(-0.18),vec3(0.18)));
	ALBEDO = clamp(color,vec3(0.0),vec3(1.0));
	ROUGHNESS = clamp(rough,0.18,1.0);
	METALLIC = metal;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.35;
	AO = 1.0-cavity;
	AO_LIGHT_AFFECT = 0.2;
}
