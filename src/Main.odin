package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/linalg/glsl"

import "vendor:raylib"

Circle :: struct {
	using position: glsl.dvec2,
	velocity:       glsl.dvec2,
	acceleration:   glsl.dvec2,
	radius:         f64,
	mass:           f64,
}

IsColliding :: proc(a, b: Circle) -> bool {
	return(
		glsl.dot(b.position - a.position, b.position - a.position) <
		(a.radius + b.radius) * (a.radius + b.radius) \
	)
}

ResolveCollision :: proc(a, b: Circle) -> (new_a_velocity, new_b_velocity: glsl.dvec2) {
	// https://en.wikipedia.org/wiki/Elastic_collision
	new_a_velocity =
		a.velocity -
		((2 * b.mass) / (a.mass + b.mass)) *
			(glsl.dot(a.velocity - b.velocity, a.position - b.position) /
					glsl.dot(a.position - b.position, a.position - b.position)) *
			(a.position - b.position)
	new_b_velocity =
		b.velocity -
		((2 * a.mass) / (a.mass + b.mass)) *
			(glsl.dot(b.velocity - a.velocity, b.position - a.position) /
					glsl.dot(b.position - a.position, b.position - a.position)) *
			(b.position - a.position)
	return
}

GRAVITY :: false
G :: 5

StepPhysics :: proc(circles: []Circle, time_step: f64) {
	for i in 0 ..< len(circles) {
		a := &circles[i]
		for j in i + 1 ..< len(circles) {
			b := &circles[j]

			when GRAVITY {
				a_to_b := b.position - a.position
				force := (G * a.mass * b.mass) / glsl.dot(a_to_b, a_to_b)
				direction := glsl.normalize(a_to_b)
				a.acceleration += direction * force / a.mass
				b.acceleration -= direction * force / b.mass
			}

			if IsColliding(a^, b^) {
				a.velocity, b.velocity = ResolveCollision(a^, b^)
			}
		}
	}
	for i in 0 ..< len(circles) {
		circle := &circles[i]
		circle.velocity += circle.acceleration * time_step
		circle.position += circle.velocity * time_step
		circle.acceleration = 0.0
	}
}

main :: proc() {
	WIDTH :: 640
	HEIGHT :: 480

	raylib.InitWindow(WIDTH, HEIGHT, "Reversible Physics")
	defer raylib.CloseWindow()

	SCALE :: 10.0
	camera := raylib.Camera2D {
		offset = {WIDTH / 2.0, HEIGHT / 2.0},
		target = {0.0, 0.0},
		rotation = 0.0,
		zoom = (HEIGHT if WIDTH > HEIGHT else WIDTH) / (SCALE * 2.0),
	}

	circles := [dynamic]Circle{
		Circle{position = {-2.0, 1.0}, velocity = {0.0, 0.0}, radius = 1.0, mass = 1.0},
		Circle{position = {2.0, 0.0}, velocity = {-5.0, 0.0}, radius = 1.0, mass = 2.0},
	}
	defer delete(circles)

	FPS :: 60
	raylib.SetTargetFPS(FPS)

	steps: u128 = 0
	time_direction := 1.0
	fixed_time := 0.0
	for !raylib.WindowShouldClose() {
		dt := f64(raylib.GetFrameTime())
		if raylib.IsKeyPressed(.SPACE) {
			time_direction = -time_direction
		}

		TimeStepSize :: 1.0 / FPS
		MinStepSize :: 0.001
		fixed_time += dt
		for fixed_time >= TimeStepSize {
			min_time := TimeStepSize
			for i in 0 ..< len(circles) {
				a := &circles[i]
				for j in i + 1 ..< len(circles) {
					b := &circles[j]
					relative_velocity := abs(
						glsl.dot(b.velocity - a.velocity, b.position - a.position),
					)
					distance :=
						glsl.distance(a.position, b.position) - (a.radius + b.radius)
					min_time = max(
						MinStepSize,
						min(min_time, distance / relative_velocity),
					)
				}
			}
			StepPhysics(circles[:], time_direction * min_time)
			fixed_time -= min_time
			steps += 1
		}

		raylib.BeginDrawing()
		defer raylib.EndDrawing()

		raylib.ClearBackground({51, 51, 51, 255})
		{
			raylib.BeginMode2D(camera)
			defer raylib.EndMode2D()
			for circle in circles {
				raylib.DrawCircleV(
					{f32(circle.x), -f32(circle.y)},
					f32(circle.radius),
					raylib.RED,
				)
			}
		}

		text_y_offset := i32(5)
		raylib.DrawText(
			"Forward" if time_direction > 0 else "Reverse",
			5,
			text_y_offset,
			25,
			raylib.WHITE,
		)
		text_y_offset += 25

		energy := 0.0
		for i in 0 ..< len(circles) {
			a := &circles[i]
			energy += 0.5 * a.mass * glsl.dot(a.velocity, a.velocity)
			for j in i + 1 ..< len(circles) {
				b := &circles[j]
				when GRAVITY {
					height :=
						glsl.distance(a.position, b.position) - (a.radius + b.radius)
					energy += a.mass * b.mass * G * height
					energy += b.mass * a.mass * G * height
				}
			}
		}
		raylib.DrawText(
			strings.unsafe_string_to_cstring(fmt.tprintf("Energy: %.3f\x00", energy)),
			5,
			text_y_offset,
			25,
			raylib.WHITE,
		)
		text_y_offset += 25

		raylib.DrawText(
			strings.unsafe_string_to_cstring(fmt.tprintf("Steps: %d\x00", steps)),
			5,
			text_y_offset,
			25,
			raylib.WHITE,
		)
		text_y_offset += 25
	}
}
