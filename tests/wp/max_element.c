/*@
   predicate is_valid_int_range(int* p, int n) =
           (0 <= n) && \valid_range(p,0,n-1);

   lemma foo: \forall int* p,n; is_valid_int_range(p,n) <==> \valid_range(p,0,n-1);

*/
/*@
   predicate
     found{A}(int* a, int n, int val) =
       \exists int i; 0 <= i < n && a[i] == val;
*/
/*@
   predicate
     found_first_of{A}(int* a, int m, int* b, int n) =
       \exists int i; 0 <= i < m && found{A}(b, n, \at(a[i],A));
*/

/*@
   requires is_valid_int_range(a, n);

   assigns \nothing;

   behavior empty:
     assumes n == 0;
     ensures \result == 0;

   behavior not_empty:
     assumes 0 < n;
     ensures 0 <= \result < n;
     ensures \forall int i; 0 <= i < n       ==> a[i] <= a[\result];
     ensures \forall int i; 0 <= i < \result ==> a[i] < a[\result];

   complete behaviors empty, not_empty;
   disjoint behaviors empty, not_empty;
*/
int max_element(const int* a, int n)
{
  if (n == 0) return 0;
  int max = 0;
  /*@
     loop invariant 0 <= i <= n;
     loop invariant 0 <= max < n;
     loop invariant \forall int k; 0 <= k < i   ==> a[k] <= a[max];
     loop invariant \forall int k; 0 <= k < max ==> a[k] < a[max];
     loop   variant n-i;
  */
  for (int i = 0; i < n; i++)
     if (a[max] < a[i])
       max = i;

  return max;
}

int main (void) { return 0 ; }