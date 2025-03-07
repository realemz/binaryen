;; NOTE: Assertions have been generated by update_lit_checks.py and should not be edited.
;; RUN: wasm-opt %s --remove-unused-names --coalesce-locals -all -S -o - \
;; RUN:   | filecheck %s

;; --remove-unused-names is run to avoid adding names to blocks. Block names
;; can prevent non-nullable local validation (we emit named blocks in the binary
;; format, if we need them, but never emit unnamed ones), which affects some
;; testcases.

(module
 ;; CHECK:      (type $A (struct (field structref)))

 ;; CHECK:      (type $array (array (mut i8)))
 (type $array (array (mut i8)))

 (type $A (struct_subtype (field (ref null struct)) data))

 ;; CHECK:      (type $B (struct_subtype (field (ref struct)) $A))
 (type $B (struct_subtype (field (ref struct)) $A))

 ;; CHECK:      (global $global (ref null $array) (ref.null none))
 (global $global (ref null $array) (ref.null $array))

 ;; CHECK:      (func $test-dead-get-non-nullable (type $ref|struct|_=>_none) (param $0 (ref struct))
 ;; CHECK-NEXT:  (unreachable)
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (block (result (ref struct))
 ;; CHECK-NEXT:    (unreachable)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $test-dead-get-non-nullable (param $func (ref struct))
  (unreachable)
  (drop
   ;; A useless get (that does not read from any set, or from the inputs to the
   ;; function). Normally we replace such gets with nops as best we can, but in
   ;; this case the type is non-nullable, so we must leave it alone.
   (local.get $func)
  )
 )

 ;; CHECK:      (func $br_on_null (type $ref?|$array|_=>_ref?|$array|) (param $0 (ref null $array)) (result (ref null $array))
 ;; CHECK-NEXT:  (block $label$1 (result (ref null $array))
 ;; CHECK-NEXT:   (block $label$2
 ;; CHECK-NEXT:    (br $label$1
 ;; CHECK-NEXT:     (br_on_null $label$2
 ;; CHECK-NEXT:      (local.get $0)
 ;; CHECK-NEXT:     )
 ;; CHECK-NEXT:    )
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (local.set $0
 ;; CHECK-NEXT:    (global.get $global)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (local.get $0)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $br_on_null (param $ref (ref null $array)) (result (ref null $array))
  (local $1 (ref null $array))
  (block $label$1 (result (ref null $array))
   (block $label$2
    (br $label$1
     ;; Test that we properly model the basic block connections around a
     ;; BrOnNull. There should be a branch to $label$2, and also a fallthrough.
     ;; As a result, the local.set below is reachable, and should not be
     ;; eliminated (turned into a drop).
     (br_on_null $label$2
      (local.get $ref)
     )
    )
   )
   (local.set $1
    (global.get $global)
   )
   (local.get $1)
  )
 )

 ;; CHECK:      (func $nn-dead (type $none_=>_none)
 ;; CHECK-NEXT:  (local $0 funcref)
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (ref.func $nn-dead)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (block $inner
 ;; CHECK-NEXT:   (local.set $0
 ;; CHECK-NEXT:    (ref.func $nn-dead)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (br_if $inner
 ;; CHECK-NEXT:    (i32.const 1)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (ref.as_non_null
 ;; CHECK-NEXT:    (local.get $0)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $nn-dead
  (local $x (ref func))
  (local.set $x
   (ref.func $nn-dead) ;; this will be removed, as it is not needed.
  )
  (block $inner
   (local.set $x
    (ref.func $nn-dead) ;; this is not enough for validation of the get, so we
                        ;; will end up making the local nullable.
   )
   ;; refer to $inner to keep the name alive (see the next testcase)
   (br_if $inner
    (i32.const 1)
   )
  )
  (drop
   (local.get $x)
  )
 )

 ;; CHECK:      (func $nn-dead-nameless (type $none_=>_none)
 ;; CHECK-NEXT:  (local $0 (ref func))
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (ref.func $nn-dead)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (block
 ;; CHECK-NEXT:   (local.set $0
 ;; CHECK-NEXT:    (ref.func $nn-dead)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (local.get $0)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $nn-dead-nameless
  (local $x (ref func))
  (local.set $x
   (ref.func $nn-dead)
  )
  ;; As above, but now the block has no name. Nameless blocks do not interfere
  ;; with validation, so we can keep the local non-nullable.
  (block
   (local.set $x
    (ref.func $nn-dead)
   )
  )
  (drop
   (local.get $x)
  )
 )

 ;; CHECK:      (func $unreachable-get-null (type $none_=>_none)
 ;; CHECK-NEXT:  (local $0 anyref)
 ;; CHECK-NEXT:  (local $1 i31ref)
 ;; CHECK-NEXT:  (unreachable)
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (block (result anyref)
 ;; CHECK-NEXT:    (unreachable)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (block (result i31ref)
 ;; CHECK-NEXT:    (i31.new
 ;; CHECK-NEXT:     (i32.const 0)
 ;; CHECK-NEXT:    )
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $unreachable-get-null
  ;; Check that we don't replace the local.get $null with a ref.null, which
  ;; would have a more precise type.
  (local $null-any anyref)
  (local $null-i31 i31ref)
  (unreachable)
  (drop
   (local.get $null-any)
  )
  (drop
   (local.get $null-i31)
  )
 )

 ;; CHECK:      (func $remove-tee-refinalize (type $ref?|$A|_ref?|$B|_=>_structref) (param $0 (ref null $A)) (param $1 (ref null $B)) (result structref)
 ;; CHECK-NEXT:  (struct.get $A 0
 ;; CHECK-NEXT:   (block (result (ref null $A))
 ;; CHECK-NEXT:    (local.get $1)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $remove-tee-refinalize
  (param $a (ref null $A))
  (param $b (ref null $B))
  (result (ref null struct))
  ;; The local.tee receives a $B and flows out an $A. We want to avoid changing
  ;; types here, so we'll wrap it in a block, and leave further improvements
  ;; for other passes.
  (struct.get $A 0
   (local.tee $a
    (local.get $b)
   )
  )
 )

 ;; CHECK:      (func $remove-tee-refinalize-2 (type $ref?|$A|_ref?|$B|_=>_structref) (param $0 (ref null $A)) (param $1 (ref null $B)) (result structref)
 ;; CHECK-NEXT:  (struct.get $A 0
 ;; CHECK-NEXT:   (block (result (ref null $A))
 ;; CHECK-NEXT:    (local.get $1)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $remove-tee-refinalize-2
  (param $a (ref null $A))
  (param $b (ref null $B))
  (result (ref null struct))
  ;; As above, but with an extra tee in the middle. The result should be the
  ;; same.
  (struct.get $A 0
   (local.tee $a
    (local.tee $a
     (local.get $b)
    )
   )
  )
 )

 ;; CHECK:      (func $replace-i31-local (type $none_=>_i32) (result i32)
 ;; CHECK-NEXT:  (local $0 i31ref)
 ;; CHECK-NEXT:  (i32.add
 ;; CHECK-NEXT:   (unreachable)
 ;; CHECK-NEXT:   (ref.is_i31
 ;; CHECK-NEXT:    (ref.cast null i31
 ;; CHECK-NEXT:     (block (result i31ref)
 ;; CHECK-NEXT:      (i31.new
 ;; CHECK-NEXT:       (i32.const 0)
 ;; CHECK-NEXT:      )
 ;; CHECK-NEXT:     )
 ;; CHECK-NEXT:    )
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $replace-i31-local (result i32)
  (local $local i31ref)
  (i32.add
   (unreachable)
   (ref.test i31
    (ref.cast null i31
     ;; This local.get is in unreachable code, and coalesce-locals will remove
     ;; it in order to avoid using the local index at all. While doing so it
     ;; must emit something of the exact same type so validation still works
     ;; (we can't turn this into a non-nullable reference, in particular - that
     ;; would hit a validation error as the cast outside of us is nullable).
     (local.get $local)
    )
   )
  )
 )

 ;; CHECK:      (func $replace-struct-param (type $f64_ref?|$A|_=>_f32) (param $0 f64) (param $1 (ref null $A)) (result f32)
 ;; CHECK-NEXT:  (call $replace-struct-param
 ;; CHECK-NEXT:   (block (result f64)
 ;; CHECK-NEXT:    (unreachable)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (ref.cast null $A
 ;; CHECK-NEXT:    (block (result (ref null $A))
 ;; CHECK-NEXT:     (struct.new_default $A)
 ;; CHECK-NEXT:    )
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $replace-struct-param (param $unused f64) (param $A (ref null $A)) (result f32)
  ;; As above, but now the value is a struct reference and it is on a local.tee.
  ;; Again, we should replace the local operation with something of identical
  ;; type to avoid a validation error.
  (call $replace-struct-param
   (block (result f64)
    (unreachable)
   )
   (ref.cast null $A
    (local.tee $A
     (struct.new_default $A)
    )
   )
  )
 )
)
