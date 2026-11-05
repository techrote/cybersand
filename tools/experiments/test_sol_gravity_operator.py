import copy
import unittest
import sol_gravity_operator_reduce as r

class OperatorTests(unittest.TestCase):
    def test_gravity_and_each_equation(self):
        self.assertEqual(r.predict([2,1,.3],[0,60],0,0,'gravity-only','float64'),[2,2,.3])
        for precision in ['float64','float32']:
            for model in r.MODELS:
                self.assertEqual(r.predict([0,0,0],[0,0],0,0,model,precision),[0,0,0])
    def test_order_is_discriminating(self):
        a=r.predict([2,1,.3],[0,60],1,1,r.MODELS[1],'float64')
        b=r.predict([2,1,.3],[0,60],1,1,r.MODELS[2],'float64')
        self.assertGreater(abs(a[1]-b[1]),1e-5)
    def test_explicit_float32(self):
        self.assertEqual(r.predict([0,0,0],[0,38],0,0,'gravity-only','float32')[1],r.f32(r.f32(38)*r.f32(1/60)))
    def test_linear_law_does_not_reverse(self):
        self.assertEqual(r.predict([2,1,.3],[0,60],100,100,r.MODELS[3],'float64'),[0,0,0])
    def test_unknown_model_is_error(self):
        with self.assertRaises(ValueError):r.predict([0,0,0],[0,0],0,0,'unknown','float64')

if __name__=='__main__':unittest.main()
